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
wwwname = "www." + domain_name
begin
  puts "creating stack"
  stack = cf.create_stack({
      stack_name: "my-stack",
      template_body: file,
      parameters: [
      { parameter_key: 'CertificateARN', parameter_value: keys['aws']['certificate_arn']},
      { parameter_key: 'RootDomainName', parameter_value: domain_name},
      { parameter_key: 'WWWName',        parameter_value: wwwname}]
  })
  #WAIT
  puts "instantiating waiter and waiting for stack creation completion. With cloudfront, this will take a while"
  waiter = Aws::CloudFormation::Waiters::StackCreateComplete.new({
    client: cf,
    max_attempts: 20000,
    delay: 60
  })
  waiter.wait({
    stack_name: "my-stack"
  })
  puts "done with stack creation!"
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
policy = File.read("bucket_policy.json")
resp = client.put_bucket_policy({
  bucket: domain_name,
  policy: policy
})
begin
  uri = URI.parse("https://" + domain_name)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Get.new(uri.request_uri)
  puts "sending response"
  response = http.request(req)
  if response.body.eql? index_file
    puts "Test complete! HTTPs works and the file requested from the domain name matches the index.html file"
  else
    puts "oops, something went wrong."
    pry
  end
rescue
  puts "Server not configured correctly, or some other error happened"
  pry
end
