require 'puppet'
require 'yaml'
require 'json'
require 'faraday'

Puppet::Reports.register_report(:slack) do

  desc <<-DESC
  Send notification of puppet run reports to Slack Messaging.
  DESC

  @configfile = File.join(File.dirname(Puppet.settings[:config]), "slack.yaml")
  raise(Puppet::ParseError, "Slack report config file #{@configfile} not readable") unless File.exist?(@configfile)
  @config = YAML.load_file(@configfile)
  SLACK_WEBHOOK = @config[:slack_webhook]
  SLACK_CHANNEL = @config[:slack_channel]
  SLACK_BOTNAME = @config[:slack_botname]
  SLACK_ICONURL = @config[:slack_iconurl]

  def process
    if self.status == "failed" or self.status == "changed"
      Puppet.debug "Sending status for #{self.host} to Slack."
      conn = Faraday.new(:url => "#{SLACK_WEBHOOK}") do |faraday|
          faraday.request  :url_encoded
          faraday.adapter  Faraday.default_adapter
      end

      color = case self.status
              when 'failed'
                'danger'
              when 'changed'
                'good'
              else
                'warning'
              end

      message = { :channel =>  SLACK_CHANNEL,
                  :username => SLACK_BOTNAME,
                  :icon_url => SLACK_ICONURL,
                  :attachments => [{ :fallback => "#{self.host} #{self.environment}: `#{self.status}` at #{Time.now.asctime}",
                                  :color => color,
                                  :text => "#{self.host} #{self.environment}: `#{self.status}` at #{Time.now.asctime}",
                                  :mrkdwn_in => ["text"] }]}

      conn.post do |req|
        req.body = JSON.dump(message)
      end
    end
  end
end
