defmodule NepeanCircular.Pdf do
  @moduledoc """
  Downloads individual flyer PDFs and combines them into a single file
  using qpdf for merging and Ghostscript for PDF generation.

  No Python runtime dependency — all PDF operations use CLI tools:
  - `qpdf` — streaming PDF merge (very memory-efficient)
  - `gs` (Ghostscript) — image→PDF, TOC generation with pdfmark links,
    and email PDF compression
  """

  require Logger

  alias NepeanCircular.Flyers
  alias NepeanCircular.HTTP

  @combined_filename "weekly-flyers.pdf"
  @combined_email_filename "weekly-flyers-email.pdf"
  @email_max_bytes 9_500_000

  defp data_dir do
    Application.app_dir(:nepean_circular, "data")
  end

  @doc """
  Returns the URL path to the combined PDF for use in templates.
  """
  def combined_pdf_path, do: "/flyers/combined.pdf"

  @doc """
  Returns the filesystem path to the combined PDF.
  """
  def combined_pdf_file, do: Path.join(data_dir(), @combined_filename)

  @doc """
  Returns the filesystem path to the low-res email PDF.
  """
  def combined_email_pdf_file, do: Path.join(data_dir(), @combined_email_filename)

  @doc """
  Returns true if a combined PDF exists on disk.
  """
  def combined_pdf_exists?, do: File.exists?(combined_pdf_file())

  @doc """
  Removes all generated PDFs from the data directory.
  """
  def clean_generated_pdfs do
    dir = data_dir()

    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".pdf"))
      |> Enum.each(fn file ->
        File.rm(Path.join(dir, file))
      end)
    end
  end

  @doc """
  Downloads current flyer PDFs from all active stores and combines them
  into a single PDF. Returns `{:ok, path}` or `{:error, reason}`.
  """
  def generate_combined do
    with {:ok, stores} <- Flyers.list_stores() do
      store_paths =
        stores
        |> Enum.filter(& &1.active)
        |> Enum.flat_map(fn store ->
          case Flyers.current_flyer_for_store(store.id) do
            {:ok, [flyer | _]} -> [{store.name, resolve_pdf(store, flyer)}]
            _ -> []
          end
        end)
        |> Enum.filter(fn {_name, result} -> match?({:ok, _}, result) end)
        |> Enum.map(fn {name, {:ok, path}} -> {name, path} end)

      combine_pdfs(store_paths)
    end
  end

  @doc """
  Downloads flyer images from URLs and converts them into a single PDF
  stored in the data directory. Returns `{:ok, path}` or `{:error, reason}`.

  Uses Ghostscript to render a PostScript program that loads and embeds
  each image as a PDF page with optional downscaling.

  The `store_key` is used to name the output file (e.g., "green_fresh").
  """
  def images_to_pdf(image_urls, store_key) do
    File.mkdir_p!(data_dir())
    output = Path.join(data_dir(), "#{store_key}_flyer.pdf")
    tmp_dir = System.tmp_dir!()

    Logger.info("Converting #{length(image_urls)} images to PDF for #{store_key}")

    image_paths =
      image_urls
      |> Enum.with_index()
      |> Enum.map(fn {url, idx} ->
        HTTP.download(url, Path.join(tmp_dir, "nepean_circular_#{store_key}_#{idx}.img"))
      end)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, path} -> path end)

    convert_images_to_pdf(image_paths, output, store_key)
  end

  defp convert_images_to_pdf([], _output, store_key) do
    Logger.warning("No images downloaded for #{store_key}")
    {:error, :no_images}
  end

  defp convert_images_to_pdf(image_paths, output, _store_key) do
    # Convert each image to an individual PDF, then merge them.
    # This avoids complex PostScript and lets GS handle each format natively.
    pdf_paths =
      image_paths
      |> Enum.map(&image_to_single_pdf/1)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, path} -> path end)

    result =
      if pdf_paths == [] do
        {:error, :conversion_failed}
      else
        case qpdf_merge(pdf_paths, output) do
          :ok ->
            Logger.info("Image-based PDF generated: #{output}")
            {:ok, output}

          {:error, reason} ->
            {:error, reason}
        end
      end

    # Cleanup intermediate PDFs and downloaded images
    Enum.each(pdf_paths, &File.rm/1)
    cleanup_temps(image_paths)
    result
  end

  # Converts a single image file (PNG, JPEG, etc.) to a single-page PDF
  # using ImageMagick's `convert` command. This handles all common image
  # formats reliably without complex PostScript.
  #
  # Returns {:ok, path} or {:error, reason}.
  defp image_to_single_pdf(image_path) do
    output = image_path <> ".pdf"

    case System.cmd("convert", [image_path, output], stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, output}

      {err, code} ->
        Logger.warning("Image convert failed for #{image_path} (exit #{code}): #{err}")
        {:error, {:convert_failed, code}}
    end
  end

  # Local file paths (from image-based scrapers) use file:// scheme
  defp resolve_pdf(store, %{pdf_url: "file://" <> local_path}) do
    if File.exists?(local_path) do
      Logger.info("Using local PDF for #{store.name}: #{local_path}")
      {:ok, local_path}
    else
      Logger.warning("Local PDF missing for #{store.name}: #{local_path}")
      {:error, :file_not_found}
    end
  end

  defp resolve_pdf(store, flyer) do
    safe_name = store.name |> String.replace(~r/[^a-zA-Z0-9]/, "_") |> String.downcase()
    dest = Path.join(System.tmp_dir!(), "nepean_circular_#{safe_name}.pdf")

    Logger.info("Downloading PDF for #{store.name}: #{flyer.pdf_url}")

    case HTTP.download(flyer.pdf_url, dest) do
      {:ok, _} = result ->
        Logger.info("Downloaded #{store.name} flyer to #{dest}")
        result

      {:error, reason} ->
        Logger.warning("Failed to download #{store.name} flyer: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp combine_pdfs([]) do
    Logger.warning("No PDFs downloaded — nothing to combine")
    {:error, :no_pdfs}
  end

  defp combine_pdfs(store_paths) do
    File.mkdir_p!(data_dir())
    output = combined_pdf_file()
    paths = Enum.map(store_paths, fn {_name, path} -> path end)

    Logger.info("Combining #{length(paths)} PDFs with qpdf")

    # Step 1: Determine target page width (most common across all store PDFs)
    target_width = find_target_width(store_paths)
    Logger.info("Target page width: #{target_width} pts")

    # Step 2: Normalize all store PDFs to the target width
    {normalized_store_paths, normalized_temps} = normalize_store_pdfs(store_paths, target_width)

    # Step 3: Count pages per normalized PDF for TOC link targets
    store_page_info =
      normalized_store_paths
      |> Enum.map(fn {name, path} -> {name, path, qpdf_page_count(path)} end)
      |> Enum.filter(fn {_name, _path, count} -> count > 0 end)

    if store_page_info == [] do
      Logger.warning("No valid PDFs found — nothing to combine")
      cleanup_temps(paths ++ normalized_temps)
      {:error, :no_pdfs}
    else
      # Step 4: Generate TOC PDF with clickable pdfmark links (using target width)
      toc_result = generate_toc_pdf(store_page_info, target_width)

      # Step 5: Merge TOC + all normalized store PDFs with qpdf
      merge_result =
        case toc_result do
          {:ok, toc_path} ->
            all_inputs = [toc_path | Enum.map(store_page_info, fn {_n, p, _c} -> p end)]
            qpdf_merge(all_inputs, output)

          {:error, _} ->
            # Fall back to merging without TOC
            inputs = Enum.map(store_page_info, fn {_n, p, _c} -> p end)
            qpdf_merge(inputs, output)
        end

      # Cleanup
      case toc_result do
        {:ok, toc_path} -> File.rm(toc_path)
        _ -> :ok
      end

      cleanup_temps(paths ++ normalized_temps)

      case merge_result do
        :ok ->
          Logger.info("Combined PDF generated: #{output}")
          generate_email_pdf(output)
          {:ok, output}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Returns a list of page widths (in PDF points) for a given PDF file.
  # Uses qpdf JSON output to read MediaBox from each page object.
  defp get_page_widths(path) do
    case System.cmd("qpdf", ["--json=2", path], stderr_to_stdout: true) do
      {json_output, code} when code in [0, 3] ->
        case Jason.decode(json_output) do
          {:ok, %{"pages" => pages, "qpdf" => [_header, objects]}} ->
            Enum.map(pages, fn %{"object" => obj_ref} ->
              obj_key = "obj:#{obj_ref}"
              mediabox_width_from_object(objects, obj_key)
            end)
            |> Enum.reject(&is_nil/1)

          _ ->
            []
        end

      {err, code} ->
        Logger.warning(
          "qpdf JSON failed for #{path} (exit #{code}): #{String.slice(err, 0, 200)}"
        )

        []
    end
  end

  # Extracts the width from a page object's /MediaBox, falling back to
  # the parent /Pages node if /MediaBox is inherited.
  defp mediabox_width_from_object(objects, obj_key) do
    case objects[obj_key] do
      %{"value" => %{"/MediaBox" => [_, _, w, _]}} ->
        w

      %{"value" => %{"/Parent" => parent_ref}} ->
        parent_key = "obj:#{parent_ref}"

        case objects[parent_key] do
          %{"value" => %{"/MediaBox" => [_, _, w, _]}} -> w
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # Determines the target page width by finding the most common width
  # (rounded to nearest integer) across all store PDFs.
  defp find_target_width(store_paths) do
    all_widths =
      store_paths
      |> Enum.flat_map(fn {_name, path} -> get_page_widths(path) end)
      |> Enum.map(&round/1)

    if all_widths == [] do
      612
    else
      all_widths
      |> Enum.frequencies()
      |> Enum.max_by(fn {_width, count} -> count end)
      |> elem(0)
    end
  end

  # Normalizes each store PDF to the target width using Ghostscript.
  # Returns {normalized_store_paths, temp_files_to_cleanup}.
  defp normalize_store_pdfs(store_paths, target_width) do
    {normalized, temps} =
      Enum.map_reduce(store_paths, [], fn {name, path}, acc_temps ->
        case normalize_pdf_width(path, target_width) do
          {:ok, ^path} ->
            # Already correct width, no temp file created
            {{name, path}, acc_temps}

          {:ok, normalized_path} ->
            Logger.info("Normalized #{name} to #{target_width}pt width")
            {{name, normalized_path}, [normalized_path | acc_temps]}

          {:error, _} ->
            # Normalization failed, use original
            Logger.warning("Width normalization failed for #{name}, using original")
            {{name, path}, acc_temps}
        end
      end)

    {normalized, temps}
  end

  # Normalizes a PDF's page widths to the target width using Ghostscript.
  # Uses a PostScript BeginPage procedure that dynamically scales each page
  # and adjusts the output page size proportionally.
  # Returns {:ok, path} (possibly the original if no scaling needed).
  defp normalize_pdf_width(path, target_width) do
    widths = get_page_widths(path)
    needs_scaling = Enum.any?(widths, fn w -> abs(w - target_width) > 1 end)

    if needs_scaling do
      output =
        Path.join(
          System.tmp_dir!(),
          "nepean_normalized_#{:erlang.unique_integer([:positive])}.pdf"
        )

      ps_file =
        Path.join(
          System.tmp_dir!(),
          "nepean_normalize_#{:erlang.unique_integer([:positive])}.ps"
        )

      ps_content = """
      /target_w #{target_width} def
      << /BeginPage {
        pop
        currentpagedevice /PageSize get aload pop
        /cur_h exch def
        /cur_w exch def
        cur_w target_w sub abs 1 gt {
          target_w cur_w div /sf exch def
          << /PageSize [target_w cur_h sf mul] >> setpagedevice
          sf sf scale
        } if
      } >> setpagedevice
      """

      File.write!(ps_file, ps_content)

      args = [
        "-sDEVICE=pdfwrite",
        "-dCompatibilityLevel=1.4",
        "-dNOPAUSE",
        "-dBATCH",
        "-dQUIET",
        "-sOutputFile=#{output}",
        "-f",
        ps_file,
        path
      ]

      result =
        case System.cmd("gs", args, stderr_to_stdout: true) do
          {_, 0} ->
            {:ok, output}

          {gs_output, code} ->
            Logger.warning(
              "GS width normalization failed (exit #{code}): #{String.slice(gs_output, 0, 200)}"
            )

            {:error, {:gs_failed, code}}
        end

      File.rm(ps_file)
      result
    else
      {:ok, path}
    end
  end

  # Returns the page count for a PDF file using qpdf.
  defp qpdf_page_count(path) do
    case System.cmd("qpdf", ["--show-npages", path], stderr_to_stdout: true) do
      {output, 0} ->
        output |> String.trim() |> String.to_integer()

      {err, code} ->
        Logger.warning("qpdf --show-npages failed for #{path} (exit #{code}): #{err}")
        0
    end
  end

  # Merges multiple PDF files into one using qpdf (streaming, memory-efficient).
  defp qpdf_merge(input_paths, output) do
    # Syntax: qpdf --empty --pages file1.pdf file2.pdf ... -- output.pdf
    args = ["--empty", "--pages"] ++ input_paths ++ ["--", output]

    case System.cmd("qpdf", args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      # qpdf exit code 3 = warnings (output still produced and valid)
      {_, 3} ->
        if File.exists?(output), do: :ok, else: {:error, :qpdf_failed}

      {err, code} ->
        Logger.warning("qpdf merge failed (exit #{code}): #{err}")
        {:error, {:qpdf_failed, code}}
    end
  end

  # Generates a TOC PDF page using Ghostscript with pdfmark annotations.
  # The TOC contains the title "This Week's Flyers" and a clickable link
  # for each store that jumps to the corresponding section in the final PDF.
  # The page width matches the target width used for normalization.
  defp generate_toc_pdf(store_page_info, page_width) do
    toc_path =
      Path.join(
        System.tmp_dir!(),
        "nepean_circular_toc_#{:erlang.unique_integer([:positive])}.pdf"
      )

    # Layout constants (in PDF points, 72 pt = 1 inch)
    margin = 60
    title_size = 28
    item_size = 18
    line_spacing = 36
    title_bottom_margin = 24

    # Calculate page height based on content
    content_height =
      margin + title_size + title_bottom_margin +
        length(store_page_info) * line_spacing + margin

    page_height = max(400, content_height)

    # Calculate cumulative page offsets (TOC is page 1, stores start at page 2)
    {store_entries, _} =
      Enum.map_reduce(store_page_info, 1, fn {name, _path, count}, acc ->
        # acc is 1-based page number in the final doc (1 = TOC page)
        {{name, acc + 1}, acc + count}
      end)

    # Build PostScript with pdfmark annotations
    title = "This Week's Flyers"
    title_x = margin
    title_y = page_height - margin - title_size

    ps_lines = [
      "%!PS-Adobe-3.0",
      "<< /PageSize [#{page_width} #{page_height}] >> setpagedevice",
      "",
      "%% --- Title ---",
      "/Helvetica-Bold findfont #{title_size} scalefont setfont",
      "0.12 0.12 0.12 setrgbcolor",
      "#{title_x} #{title_y} moveto",
      "(#{ps_escape(title)}) show",
      ""
    ]

    # Draw each store name and add a pdfmark link annotation
    {item_lines, _} =
      Enum.map_reduce(store_entries, 0, fn {name, target_page}, idx ->
        y = title_y - title_bottom_margin - (idx + 1) * line_spacing
        x = margin + 10
        label = "\\270  #{ps_escape(name)}"

        # Approximate text width: ~0.5 * font_size * char_count for Helvetica
        approx_width = 0.55 * item_size * String.length(name) + 30

        lines = [
          "%% --- #{name} ---",
          "/Helvetica findfont #{item_size} scalefont setfont",
          "0.11 0.31 0.85 setrgbcolor",
          "#{x} #{y} moveto",
          "(#{label}) show",
          "",
          "%% Link annotation → page #{target_page}",
          "[ /Rect [#{x - 4} #{y - 4} #{x + round(approx_width) + 4} #{y + item_size + 4}]",
          "  /Border [0 0 0]",
          "  /Page #{target_page}",
          "  /View [/FitH #{page_height}]",
          "  /Subtype /Link",
          "/ANN pdfmark",
          ""
        ]

        {Enum.join(lines, "\n"), idx + 1}
      end)

    ps_content =
      Enum.join(ps_lines, "\n") <> "\n" <> Enum.join(item_lines, "\n") <> "\nshowpage\n"

    ps_file =
      Path.join(
        System.tmp_dir!(),
        "nepean_circular_toc_#{:erlang.unique_integer([:positive])}.ps"
      )

    File.write!(ps_file, ps_content)

    args = [
      "-sDEVICE=pdfwrite",
      "-dCompatibilityLevel=1.4",
      "-dNOPAUSE",
      "-dBATCH",
      "-dQUIET",
      "-sOutputFile=#{toc_path}",
      "-f",
      ps_file
    ]

    result =
      case System.cmd("gs", args, stderr_to_stdout: true) do
        {_, 0} ->
          Logger.info("TOC PDF generated with #{length(store_page_info)} store links")
          {:ok, toc_path}

        {gs_output, code} ->
          Logger.warning("Ghostscript TOC generation failed (exit #{code}): #{gs_output}")
          {:error, {:gs_failed, code}}
      end

    File.rm(ps_file)
    result
  end

  # Escapes special PostScript string characters.
  defp ps_escape(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
  end

  @doc """
  Generates a low-res email-friendly PDF from the combined high-res PDF.
  Uses aggressive Ghostscript compression to stay under Postmark's 10 MB limit.
  """
  def generate_email_pdf(source_path) do
    output = combined_email_pdf_file()

    args = [
      "-sDEVICE=pdfwrite",
      "-dCompatibilityLevel=1.4",
      "-dPDFSETTINGS=/screen",
      "-dNOPAUSE",
      "-dBATCH",
      "-dQUIET",
      # Force downsampling all color/gray images
      "-dDownsampleColorImages=true",
      "-dDownsampleGrayImages=true",
      "-dDownsampleMonoImages=true",
      # Downsample threshold of 1.0 forces re-encoding even at target DPI
      "-dColorImageDownsampleThreshold=1.0",
      "-dGrayImageDownsampleThreshold=1.0",
      "-dColorImageDownsampleType=/Bicubic",
      "-dGrayImageDownsampleType=/Bicubic",
      "-dColorImageResolution=72",
      "-dGrayImageResolution=72",
      "-dMonoImageResolution=72",
      # Lower JPEG quality for smaller file size
      "-dJPEGQ=50",
      "-dAutoFilterColorImages=false",
      "-dColorImageFilter=/DCTEncode",
      "-dAutoFilterGrayImages=false",
      "-dGrayImageFilter=/DCTEncode",
      "-sOutputFile=#{output}",
      source_path
    ]

    case System.cmd("gs", args, stderr_to_stdout: true) do
      {_, 0} ->
        original_size = File.stat!(source_path).size
        email_size = File.stat!(output).size

        Logger.info(
          "Email PDF generated: #{format_bytes(original_size)} → #{format_bytes(email_size)}"
        )

        if email_size > @email_max_bytes do
          Logger.warning(
            "Email PDF still large (#{format_bytes(email_size)}), may exceed Postmark limit"
          )
        end

        {:ok, output}

      {gs_output, code} ->
        Logger.warning("Ghostscript email PDF failed (exit #{code}): #{gs_output}")
        {:error, {:gs_failed, code}}
    end
  end

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"

  defp cleanup_temps(paths) do
    tmp_dir = System.tmp_dir!()

    Enum.each(paths, fn path ->
      if String.starts_with?(path, tmp_dir), do: File.rm(path)
    end)
  end
end
