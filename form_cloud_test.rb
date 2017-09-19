require 'aws-sdk'
require 'yaml'
require 'json'

keys = YAML.load_file('secret_keys.yaml')
ENV['AWS_ACCESS_KEY_ID'] = keys['aws']['access_key']
ENV['AWS_SECRET_ACCESS_KEY'] = keys['aws']['secret_key']
ENV['AWS_REGION'] = 'us-east-1'

file = File.read('cloudformation.yaml')

cf = Aws::CloudFormation::Client.new(validate_params: false)
stack = cf.create_stack({
    stack_name: "my-stack",
    template_body: file,
    parameters: [
    { parameter_key: 'CertificateARN', parameter_value: keys['aws']['certificate_arn'] },
    { parameter_key: 'RootDomainName', parameter_value: keys['aws']['domain_name']} ]
})
