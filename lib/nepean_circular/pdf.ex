defmodule NepeanCircular.Pdf do
  @moduledoc """
  Downloads individual flyer PDFs and combines them into a single file
  using pypdf via Pythonx.
  """

  require Logger

  alias NepeanCircular.Flyers
  alias NepeanCircular.HTTP

  @combined_filename "weekly-flyers.pdf"

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
  Returns true if a combined PDF exists on disk.
  """
  def combined_pdf_exists?, do: File.exists?(combined_pdf_file())

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
    {_result, _globals} =
      Pythonx.eval(
        """
        from PIL import Image

        images = []
        for path in image_paths:
            img = Image.open(str(path, "utf-8"))
            if img.mode == "RGBA":
                img = img.convert("RGB")
            images.append(img)

        if images:
            first, *rest = images
            first.save(str(output_path, "utf-8"), "PDF", save_all=True, append_images=rest)
        """,
        %{"image_paths" => image_paths, "output_path" => output}
      )

    Logger.info("Image-based PDF generated: #{output}")
    cleanup_temps(image_paths)
    {:ok, output}
  rescue
    e ->
      Logger.warning("Pillow image-to-PDF failed: #{Exception.message(e)}")
      cleanup_temps(image_paths)
      {:error, {:pillow_failed, Exception.message(e)}}
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
    names = Enum.map(store_paths, fn {name, _path} -> name end)
    paths = Enum.map(store_paths, fn {_name, path} -> path end)

    Logger.info("Combining #{length(paths)} PDFs with pypdf → #{output}")

    {_result, _globals} =
      Pythonx.eval(
        """
        from pypdf import PdfReader, PdfWriter
        from pypdf.annotations import Link
        from pypdf.generic import Fit, ArrayObject, FloatObject, NameObject
        from collections import Counter
        from PIL import Image, ImageDraw, ImageFont
        import io

        store_names = [str(n, "utf-8") for n in names]

        # Read all source PDFs, track which pages belong to which store
        store_page_ranges = []  # [(name, start_page, page_count)]
        all_pages = []
        for i, path in enumerate(pdf_paths):
            reader = PdfReader(str(path, "utf-8"))
            start = len(all_pages)
            for page in reader.pages:
                all_pages.append(page)
            store_page_ranges.append((store_names[i], start, len(reader.pages)))

        if not all_pages:
            raise ValueError("No pages found")

        # Find the most common page width as target
        widths = [float(p.mediabox.width) for p in all_pages]
        target_width = Counter(round(w) for w in widths).most_common(1)[0][0]

        # Build index page image with Pillow
        dpi = 72
        page_w = int(target_width)
        margin = 60
        title_size = 36
        item_size = 22
        line_spacing = 50
        title_bottom_margin = 30

        # Calculate height needed
        content_height = title_size + title_bottom_margin + len(store_names) * line_spacing + margin
        page_h = max(400, margin + content_height)

        img = Image.new("RGB", (page_w, page_h), (255, 255, 255))
        draw = ImageDraw.Draw(img)

        try:
            title_font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", title_size)
            item_font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans.ttf", item_size)
        except (OSError, IOError):
            try:
                title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", title_size)
                item_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", item_size)
            except (OSError, IOError):
                title_font = ImageFont.load_default(size=title_size)
                item_font = ImageFont.load_default(size=item_size)

        # Draw title
        title = "This Week's Flyers"
        bbox = draw.textbbox((0, 0), title, font=title_font)
        tw = bbox[2] - bbox[0]
        draw.text(((page_w - tw) / 2, margin), title, fill=(30, 30, 30), font=title_font)

        # Draw store names as list items
        y = margin + title_size + title_bottom_margin
        link_regions = []  # [(name, x, y, w, h, target_page)]
        for name, start_page, _count in store_page_ranges:
            label = f"▸  {name}"
            draw.text((margin + 10, y), label, fill=(29, 78, 216), font=item_font)
            bbox = draw.textbbox((margin + 10, y), label, font=item_font)
            text_w = bbox[2] - bbox[0]
            text_h = bbox[3] - bbox[1]
            # page numbers shift by 1 because index page is page 0
            link_regions.append((margin + 10, y, text_w, text_h, start_page + 1))
            y += line_spacing

        # Convert index image to PDF page
        index_pdf_bytes = io.BytesIO()
        img.save(index_pdf_bytes, "PDF")
        index_pdf_bytes.seek(0)
        index_reader = PdfReader(index_pdf_bytes)
        index_page = index_reader.pages[0]

        # Build the final PDF: index page first, then all content pages
        writer = PdfWriter()
        writer.add_page(index_page)

        for page in all_pages:
            pw = float(page.mediabox.width)
            ph = float(page.mediabox.height)
            if abs(pw - target_width) > 1:
                scale = target_width / pw
                new_height = ph * scale
                page.scale_by(scale)
                page.mediabox.upper_right = (target_width, new_height)
                page.mediabox.lower_left = (0, 0)
            writer.add_page(page)

        # Add clickable link annotations on the index page
        index_page_height = float(index_page.mediabox.height)
        for lx, ly, lw, lh, target_page in link_regions:
            # PDF coordinates are bottom-up, Pillow is top-down
            pdf_y_bottom = index_page_height - ly - lh - 4
            pdf_y_top = index_page_height - ly + 4
            rect = (lx - 4, pdf_y_bottom, lx + lw + 4, pdf_y_top)
            # Get the target page height so we scroll to the very top
            target_page_height = float(writer.pages[target_page].mediabox.height)
            link = Link(
                rect=rect,
                target_page_index=target_page,
                fit=Fit.fit_horizontally(top=target_page_height),
                border=[0, 0, 0],
            )
            writer.add_annotation(page_number=0, annotation=link)

        writer.write(str(output_path, "utf-8"))
        writer.close()
        """,
        %{"names" => names, "pdf_paths" => paths, "output_path" => output}
      )

    Logger.info("Combined PDF generated: #{output}")
    cleanup_temps(paths)
    {:ok, output}
  rescue
    e ->
      Logger.warning("pypdf merge failed: #{Exception.message(e)}")
      store_paths |> Enum.map(fn {_name, path} -> path end) |> cleanup_temps()
      {:error, {:pypdf_failed, Exception.message(e)}}
  end

  defp cleanup_temps(paths) do
    tmp_dir = System.tmp_dir!()

    Enum.each(paths, fn path ->
      if String.starts_with?(path, tmp_dir), do: File.rm(path)
    end)
  end
end
