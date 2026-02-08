defmodule NepeanCircular.Scraping.GreenFreshTest do
  use NepeanCircular.DataCase

  alias NepeanCircular.Scraping.GreenFresh

  describe "extract_flyer_images/1" do
    test "extracts wixstatic content images with q_90 quality" do
      html = """
      <img src="https://static.wixstatic.com/media/61ee79_abcdef012345~mv2.png/v1/fill/w_800,h_1000,q_90/61ee79_abcdef012345~mv2.png">
      <img src="https://static.wixstatic.com/media/61ee79_def456789abc~mv2.png/v1/fill/w_600,h_900,q_90/61ee79_def456789abc~mv2.png">
      <img src="https://static.wixstatic.com/media/other_logo.png/v1/fill/w_200,h_100,q_80/other_logo.png">
      """

      images = GreenFresh.extract_flyer_images(html)

      assert length(images) == 2
      assert Enum.all?(images, &String.contains?(&1, "q_90"))
    end

    test "filters out small images" do
      html = """
      <img src="https://static.wixstatic.com/media/61ee79_aaa111222333~mv2.png/v1/fill/w_100,h_100,q_90/61ee79_aaa111222333~mv2.png">
      <img src="https://static.wixstatic.com/media/61ee79_bbb444555666~mv2.png/v1/fill/w_800,h_1000,q_90/61ee79_bbb444555666~mv2.png">
      """

      images = GreenFresh.extract_flyer_images(html)

      assert length(images) == 1
      assert hd(images) =~ "bbb444555666"
    end

    test "deduplicates images by media ID and keeps largest variant" do
      html = """
      <img src="https://static.wixstatic.com/media/61ee79_ccc777888999~mv2.png/v1/fill/w_600,h_800,q_90/61ee79_ccc777888999~mv2.png">
      <img src="https://static.wixstatic.com/media/61ee79_ccc777888999~mv2.png/v1/fill/w_800,h_1000,q_90/61ee79_ccc777888999~mv2.png">
      """

      images = GreenFresh.extract_flyer_images(html)

      assert length(images) == 1
      assert hd(images) =~ "w_800"
    end

    test "returns empty list for page with no flyer images" do
      html = "<html><body><p>No images</p></body></html>"

      assert GreenFresh.extract_flyer_images(html) == []
    end
  end
end
