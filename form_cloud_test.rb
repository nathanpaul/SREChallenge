require 'aws-sdk'
require 'yaml'
require 'pry'
require "net/https"
require "uri"

keys = YAML.load_file('secret_keys.yaml')
ENV['AWS_ACCESS_KEY_ID'] = keys['aws']['access_key']
ENV['AWS_SECRET_ACCESS_KEY'] = keys['aws']['secret_key']
ENV['AWS_REGION'] = 'us-east-1'

file = File.read('cloudformation.yaml')

cf = Aws::CloudFormation::Client.new(validate_params: false)
domain_name = keys['aws']['domain_name']
begin
  puts "creating stack"
  stack = cf.create_stack({
      stack_name: "my-stack",
      template_body: file,
      parameters: [
      { parameter_key: 'CertificateARN', parameter_value: keys['aws']['certificate_arn'] },
      { parameter_key: 'RootDomainName', parameter_value: domain_name} ]
  })
  #WAIT
rescue
  puts "created stack already"
end

# once done, upload to root bucket with the index.html file.
puts "uploading file"
index_file_name = "index.html"
index_file = File.read("index.html")
client = Aws::S3::Client.new
client.put_object({
  bucket: domain_name,
  key: index_file_name,
  body: index_file
})
client.put_bucket_acl({
  acl: "public-read",
  bucket: domain_name,
})
# test that it's working with Net HTTP
begin
  uri = URI.parse("https://" + domain_name)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Get.new(uri.request_uri)
  puts "sending response"
  response = http.request(req)
  if response.body.eql? index_file
    puts "done!"
  else
    puts "oops"
  end
rescue
  puts "Server not configured correctly"
  pry
end
