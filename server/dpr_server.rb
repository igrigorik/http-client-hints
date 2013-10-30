require 'sinatra'

# Sample CH-DPR aware server.
#
# The server assumes the asset variants are pre-generated (e.g. via a build
# task) and are available on disk. To find the available variants, the server
# performs a wildcard lookup on based on the following filename pattern:
#
#   {name}-{dpr}x.{extension}
#
# Note that the wildcard lookup is just one simple strategy. Alternatively,
# a different mechanism can be used to define which breakpoints are available,
# or, a dynamic backend / service can be used to generate the appropriate
# assets on the fly.
#
# For demo purposes, the server also accepts "force_dpr" query param to
# emulate behavior of sending an equivalent "CH-DPR: x.x" request header.
#

class Image
  attr_reader :filename, :ext, :dpr, :name
  def initialize(filename)
    @filename = filename
    @ext = File.extname(filename)
    @dpr = filename.match(/(\d\.\d)x/)[1].to_f rescue nil
    @name = File.basename(filename).chomp(@ext).chomp("#{@dpr}x")
  end

  def nameonly?  ;  @dpr.nil? ; end
  def exactname? ; !@dpr.nil? ; end
end


get '/:name' do
  # use force_dpr query param to overrie CH-DPR header
  dpr = params['force_dpr'] || env['HTTP_CH_DPR']

  # parse incoming image request and build list of available variants.
  img = Image.new('assets/'+params['name'])
  variants = Dir["assets/#{img.name}*"].map {|v| Image.new(v) }
  return 400 if variants.empty?

  headers \
    "Content-Type" => "image/jpeg", # demo server always returns jpeg's...
    "Vary" => "CH-DPR"              # use CH-DPR value as part of cache key

  # fallback behavior for requests without CH-DPR header
  if dpr.nil?
    if img.exactname?
      # return exact asset (e.g. /photo-1x.jpg)
      return [200, IO.read(img.filename)]

    elsif img.nameonly?
      # if DPR is not specified in filename, return lowest available DPR
      asset = variants.min_by {|v| v.dpr }
      return [200, IO.read(asset.filename)]
    end

    return 400
  end

  # CH-DPR or force_dpr is present, find the best candidate:
  # First, find variants that are equal or less than request DPR. Note that
  # you can serve a higher DPR asset, we're just optimizing for number of
  # delivered bytes in this case. Second, find the closest variant that
  # matches the request DPR from filtered list.
  asset = variants.
    find_all {|v| v.dpr <= dpr.to_f }.
    max_by   {|v| v.dpr }

  # Set the server selection header to indicate the DPR of selected asset,
  # such that the client adjust its logic when calculating the display size.
  headers "DPR" => asset.dpr.to_s

  # Return the actual asset!
  return [200, IO.read(asset.filename)]
end
