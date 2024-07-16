defmodule ThumbHash do
  @moduledoc """
  A bridge to the Rust ThumbHash library.
  See: https://github.com/evanw/thumbhash for original implmentation.
  """

  use Rustler, otp_app: :thumb_hash

  @doc """
  Takes rgba data as a binary in u8 rgba format flattened with 4 values per pixel.
  e.g. <<r1 g1 b1 a1 r2 g2 b2 a2 ...>>
  Returns a list of integer values that make up thumbhash of the image
  Images must be pre-scaled to fit within a 100px x 100px bounding box.
  """
  @spec rgba_to_thumb_hash(non_neg_integer(), non_neg_integer(), binary()) ::
          list(non_neg_integer()) | no_return()
  def rgba_to_thumb_hash(_width, _height, _rgba), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Generates a base64 encoded thumbhash of the image located at `path`
  """
  @spec generate_base64_hash!(Path.t() | binary()) :: binary() | no_return()
  def generate_base64_hash!(path) do
    with {:ok, image} <- Image.open(path)
    do
      image
      |> Image.thumbnail!(100, export_icc_profile: :srgb)
      |> do_generate!()
    else
      {:error, error} -> raise error
    end
  end

  @doc """
  Generates a base64 encoded thumbhash of the image stored in `thumbnail`
  """
  @spec generate_base64_hash_from_binary!(binary()) :: binary() | no_return()
  def generate_base64_hash_from_binary!(buffer) do
    buffer
    |> Image.from_binary!()
    |> do_generate!()
  end

  defp do_generate!(thumbnail) do
    image_with_alpha =
      if Image.has_alpha?(thumbnail) do
        thumbnail
      else
        alpha = Image.new!(Image.width(thumbnail), Image.height(thumbnail), bands: 1, color: 255)
        Image.add_alpha!(thumbnail, alpha)
      end

    {:ok, tensor} = Vix.Vips.Image.write_to_tensor(image_with_alpha)

    %Vix.Tensor{data: data, shape: {h, w, 4}, names: [:height, :width, :bands], type: {:u, 8}} =
      tensor

    hash = rgba_to_thumb_hash(w, h, data)
    hashbin = Enum.into(hash, <<>>, fn int -> <<int::8>> end)
    Base.encode64(hashbin)
  end
end
