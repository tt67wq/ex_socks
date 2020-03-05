defmodule Common.Crypto do
  @moduledoc """
  对称加密
  """

  @doc """
  sha256
  """
  @spec sha256(String.t()) :: binary()
  def sha256(plaintext), do: :crypto.hash(:sha256, plaintext)

  # def aes_encrypt(plaintext, _key, _options \\ [base64: true]), do: plaintext
  # def aes_decrypt(ciphertext, _key, _options \\ [base64: true]), do: ciphertext
  @doc """
  aes加密
  """
  @spec aes_encrypt(String.t(), String.t(), list()) :: binary() | String.t()
  def aes_encrypt(plaintext, key, options \\ [base64: true]) do
    iv = :crypto.strong_rand_bytes(16)
    ciphertext = :crypto.block_encrypt(:aes_cbc256, sha256(key), iv, pkcs7_pad(plaintext))
    res = iv <> ciphertext

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
    {iv, target} =
      if options[:base64] do
        {:ok, <<iv::binary-16, target::binary>>} = Base.decode64(ciphertext)
        {iv, target}
      else
        <<iv::binary-16, target::binary>> = ciphertext
        {iv, target}
      end

    {:ok, plaintext} =
      :crypto.block_decrypt(:aes_cbc256, sha256(key), iv, target)
      |> pkcs7_unpad()

    plaintext
  end

  defp pkcs7_unpad(<<>>), do: :error

  defp pkcs7_unpad(message) do
    padding_size = :binary.last(message)
    {:ok, binary_part(message, 0, byte_size(message) - padding_size)}
  end
end
