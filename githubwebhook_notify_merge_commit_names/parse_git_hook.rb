# for AWS Lambda
require 'json'
require 'slack-notifier'
require 'faraday'
require 'openssl'
require 'rack'

def lambda_handler(event:, context:)
    return { statusCode: 400, body: 'invalid token' } unless verify_signature(event)
    
    req = event['body']
    if req['action'] == 'labeled' &&
      req['pull_request']['labels'].any?{ |label| label['name'] == 'deploy' }

      begin
        commits_url = req['pull_request']['commits_url']
        messages = filtered_commits_messages(commits_url)
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

def filtered_commits_messages(commits_url)
  messages = []
  request_times = 0
  
  # @notice request_times < 10 は想定外の挙動をした場合に無限ループとならないようにするため
  while !(commits_url.nil? || commits_url.empty?) && request_times < 10 do
    res = Faraday.get(commits_url)
    commits = JSON.parse(res.body)
    messages.concat(merge_commit_messages(commits))
    request_times += 1
    
    commits_url = next_link(res.headers['Link'])
  end
  messages
end

def merge_commit_messages(commits)
  commits.select do |commit|
    commit['commit']['message'].include?('Merge pull request ') 
  end.map do |commit|
    commit['commit']['message'].gsub('Merge pull request ', '').gsub("\n", ' ')
  end
end

# parse headers['Link'] and select next link
# @params header_link [String]
#   ex) <https://api.github.com/repositories/11111111111/pulls/1/commits?page=2>; rel="next", <https://api.github.com/repositories/11111111111/pulls/1/commits?page=2>; rel="last"
# @return String ページングされた次のcommitsの情報を取得するためのapiのurl
#   ex) https://api.github.com/repositories/11111111111/pulls/1/commits?page=2
def next_link(header_link)
  rels = header_link.split(',')
  url = ''

  rels.each do |rel, index|
    rel_items = rel.split(';')
    if rel_items[1][/rel="(.*)"/,1] == 'next'
      url = rel_items[0][/<(.*)>/,1]
      break
    end
  end
  url
end
