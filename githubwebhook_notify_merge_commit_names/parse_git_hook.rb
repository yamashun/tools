# for AWS Lambda
require 'json'
require 'slack-notifier'

def lambda_handler(event:, context:)
    res = JSON.parse(event['body'])
    puts res
    notifier = Slack::Notifier.new ENV['SLACK_NOTIFY_URL']
    notifier.ping "Hello World"
    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end
