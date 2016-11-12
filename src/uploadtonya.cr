require "./uploadtonya/*"
require "http/client"
require "option_parser"
require "multipart"
require "json"

auth = false
authtoken = ""
opt_filenames = [] of String

class NyaResponse
  JSON.mapping({
    success: Bool,
    files:   Array(NyaFiles),
  })
end

class NyaFiles
  JSON.mapping({
    name: String,
    url:  String,
    hash: String,
    size: Int32,
  })
end

OptionParser.parse! do |parser|
  parser.banner = "Usage: uploadtonya [th] file"
  parser.on("-t TOKEN", "--token=TOKEN", "Specify access token for nya.is") { |token| authtoken = token; auth = true }
  parser.on("-h", "--help", "Show this help") { puts parser; exit() }
  parser.unknown_args do |before, after|
    if before.size > 0
      before.each do |files|
        opt_filenames.push(files)
      end
    else
      abort("No files given")
    end
  end
end

if auth
  url = "https://nya.is/upload?token=#{authtoken}"
else
  url = "https://nya.is/upload"
end

io = MemoryIO.new
generator = HTTP::FormData::Generator.new(io, "aA47")

opt_filenames.each do |file|
  if !File.exists?(file)
    abort("File #{file} not found!")
  end
  datafile = MemoryIO.new File.read(file)
  generator.file("files[]", datafile, HTTP::FormData::FileMetadata.new(filename: File.basename(file)))
end
generator.finish

puts "Uploading..."

response = HTTP::Client.post(url, headers: HTTP::Headers{"User-Agent" => "uploadtonya.cr", "Content-Type" => generator.content_type}, body: io.to_s)

res = NyaResponse.from_json(response.body)

if !res.success
  abort("Failed to upload files")
end

res.files.each do |file|
  puts "Name: #{file.name} URL: #{file.url}"
end
