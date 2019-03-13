# for AWS Lambda
require 'json'
require 'slack-notifier'
require 'faraday'

def lambda_handler(event:, context:)
    req = event['payload']
    if req['action'] == 'labeled' &&
      req['pull_request']['labels'].any?{ |label| label['name'] == 'deploy' }

      begin
        commits_url = req['pull_request']['commits_url']
        commits = JSON.parse(Faraday.get(commits_url).body)
        messages = commits.map do |commit|
          commit['commit']['message']
        end
        notifier = Slack::Notifier.new ENV['SLACK_NOTIFY_URL']
        notifier.ping messages.join('\n')
      rescue => exception
        puts exception.message
      end
    end

    { statusCode: 200, body: 'ok' }
end
