defmodule NepeanCircular.HTTP do
  @moduledoc """
  Shared HTTP utilities for scrapers and downloaders.
  """

  @user_agent "NepeanCircular/1.0 (grocery flyer aggregator)"

  @doc """
  Returns the User-Agent header value used for all outbound requests.
  """
  def user_agent, do: @user_agent

  @doc """
  Downloads a file from `url` to `dest` path.
  Returns `{:ok, dest}` or `{:error, reason}`.
  """
  def download(url, dest) do
    opts =
      [into: File.stream!(dest), headers: [{"user-agent", @user_agent}]]
      |> Keyword.merge(req_options())

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, dest}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:download_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches a page body via GET. Returns `{:ok, body}` or `{:error, reason}`.
  """
  def get_body(url) do
    opts =
      [headers: [{"user-agent", @user_agent}]]
      |> Keyword.merge(req_options())

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp req_options do
    Application.get_env(:nepean_circular, :req_options, [])
  end
end
