defmodule Common.Crypto do
  @moduledoc """
  对称加密
  """

  @aad "IJustLikeIt"
  @tag_length 16

  @doc """
  sha256
  """
  @spec sha256(String.t()) :: binary()
  def sha256(plaintext), do: :crypto.hash(:sha256, plaintext)

  @doc """
  aes加密
  """
  @spec aes_encrypt(String.t(), String.t(), list()) :: binary() | String.t()
  def aes_encrypt(plaintext, key, options \\ [base64: true]) do
    iv = :crypto.strong_rand_bytes(16)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        sha256(key),
        iv,
        pkcs7_pad(plaintext),
        @aad,
        @tag_length,
        true
      )

    res = iv <> tag <> ciphertext

    if options[:base64], do: Base.encode64(res), else: res
  end

  # 补全至16字节整数倍
  defp pkcs7_pad(message) do
    bytes_remaining = rem(byte_size(message), 16)
    padding_size = 16 - bytes_remaining
    message <> :binary.copy(<<padding_size>>, padding_size)
  end

  @doc """
  aes解密
  """
  @spec aes_decrypt(String.t(), String.t(), list()) :: String.t()
  def aes_decrypt(ciphertext, key, options \\ [base64: true]) do
    {iv, tag, target} =
      if options[:base64] do
        {:ok, <<iv::binary-size(16), tag::binary-size(@tag_length), target::binary>>} =
          Base.decode64(ciphertext)

        {iv, tag, target}
      else
        <<iv::binary-size(16), tag::binary-size(@tag_length), target::binary>> = ciphertext
        {iv, tag, target}
      end

    # IO.inspect(iv)
    # IO.inspect(tag)
    # IO.inspect(target)

    {:ok, plaintext} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        sha256(key),
        iv,
        target,
        @aad,
        tag,
        false
      )
      |> pkcs7_unpad()

    plaintext
  end

  defp pkcs7_unpad(<<>>), do: :error

  defp pkcs7_unpad(message) do
    padding_size = :binary.last(message)
    {:ok, binary_part(message, 0, byte_size(message) - padding_size)}
  end
end
