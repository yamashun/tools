# for AWS Lambda
require 'json'
require 'slack-notifier'
require 'faraday'
require 'openssl'
require 'rack'

# commit 23
def lambda_handler(event:, context:)
    return { statusCode: 400, body: 'invalid token' } unless verify_signature(event)
    
    req = event['body']
    if req['action'] == 'labeled' &&
      req['pull_request']['labels'].any?{ |label| label['name'] == 'deploy' }

      begin
        commits_url = req['pull_request']['commits_url']
        commits = JSON.parse(Faraday.get(commits_url).body)
        messages = commits.select do |commit|
          commit['commit']['message'].include?('Merge pull request ') 
        end.map do |commit|
          commit['commit']['message'].gsub('Merge pull request ', '').gsub("\n", ' ')
        end
        unless messages.empty?
          messages.unshift("<!here>", "リリースを開始します。修正内容を確認してください。")
          notifier = Slack::Notifier.new ENV['SLACK_NOTIFY_URL']
          notifier.post text: messages.join("\n")
        end
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
