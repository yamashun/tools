# for AWS Lambda
require 'json'
require 'slack-notifier'

def lambda_handler(event:, context:)
    req = JSON.parse(event['body'])
    puts req
    res = 'ok'
    if req['action'] == 'labeld'
      req['pull_request']['labels'].any? do |label|
        # TODO: labelフォーマットを確認後に特定のラベルが存在するかをチェック
      end
    end

    puts req
    notifier = Slack::Notifier.new ENV['SLACK_NOTIFY_URL']
    notifier.ping "Hello World"
    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end
