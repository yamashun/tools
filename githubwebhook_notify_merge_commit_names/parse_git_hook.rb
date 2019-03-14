# for AWS Lambda
require 'json'
require 'slack-notifier'
require 'faraday'
require 'openssl'
require 'rack'

def lambda_handler(event:, context:)
    return { statusCode: 200, body: 'invalid token' } unless verify_signature(event)
    
    req = event['body']
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


def verify_signature(event)
  signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], event['body'].to_json)
  Rack::Utils.secure_compare(signature, event['headers']['X-Hub-Signature'])
end
