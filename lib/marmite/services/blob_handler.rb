# handles common blob-related actions
class BlobHandler
  # @param [String] string for compressing and encoding
  # @return [String] compressed and encoded version of string
  def self.compress(string)
    Base64.encode64(
        Zlib::Deflate.new(nil, -Zlib::MAX_WBITS)
                     .deflate(string, Zlib::FINISH)
    )
  end
  # @param [String] blob for decompressing
  # @return [String] metadata string
  def self.uncompress(blob)
    zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    buf = zstream.inflate(Base64::decode64(blob))
    zstream.finish
    zstream.close
    buf
  end
end