# require 'httparty'
require 'json'
require 'tzinfo'
require 'logger'
require 'uri'
require 'time'
require 'slack-ruby-client'
require 'rack'

def verify_request(event)
  env = {
    'rack.input' => StringIO.new(event['body']),
    'HTTP_X_SLACK_REQUEST_TIMESTAMP' => event.dig('headers', 'X-Slack-Request-Timestamp'),
    'HTTP_X_SLACK_SIGNATURE' => event.dig('headers', 'X-Slack-Signature')
  }
  req = Rack::Request.new(env)
  slack_request = Slack::Events::Request.new(req)
  slack_request.verify!
end

def logger
  @logger ||= Logger.new($stdout, level: Logger::Severity::DEBUG)
end

def create_local_time(time_str, _zone_abbreviation)
  Time.parse(time_str)

  # 時間の変換処理: 時間がかかりSlackの3秒のタイムアウト制限にひっかかるので実行しない
  #
  # zone = TZInfo::Timezone.all.find { _1.abbreviation == zone_abbreviation }
  # raise "Timezone not found: #{zone_abbreviation}" if zone.nil?

  # time.localtime(zone.observed_utc_offset).iso8601
rescue ArgumentError
  raise "Invalid time format: #{time_str}"
end

def lambda_handler(event:, context:)
  logger.debug(event)
  logger.debug(context)

  # SlackからのリクエストかどうかをSlackが提供する「Signing Secret」を使い検証。samconfig.tomlで設定
  verify_request(event)

  params = URI.decode_www_form(event['body']).to_h
  body = create_local_time(*params['text'].split(',').map(&:strip))

  { statusCode: 200, body: body }
rescue StandardError => e
  logger.fatal(e.full_message)
  { statusCode: 200, body: e.message }
end
