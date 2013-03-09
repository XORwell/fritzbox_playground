require 'rubygems'
require 'bundler/setup'
require 'patron'
require 'faraday'
require 'nokogiri'
require 'open-uri'
require 'nori'
require 'digest/md5'
require 'iconv'


class FritzClient

  def initialize(hostname, password, verbose=false)
    @sid = nil
    @hostname = hostname
    @password = password
    @uri = {
        :settings => "/cgi-bin/webcm?getpage=../html/de/menus/menu2.html",
        :login => "/login.lua",
        :login_sid => "/login_sid.lua",
        :home => "/home/home.lua",
        :webcm => "/cgi-bin/webcm"
    }
    @parser = Nori.new(:parser => :nokogiri)
    @conn = Faraday.new(:url => "http://#{@hostname}") do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      faraday.response :logger if verbose # log requests to STDOUT
      faraday.adapter :patron do |session|
        session.handle_cookies
      end
    end

    unless login
      raise("Login failed")
    end

  end

  # Change configuration parameters
  # Example: change_settings({"telcfg:settings/Diversity0/Active" => 0})
  # @param [Hash] params
  # @return [void]
  def change_settings(params)
    params["getpage"] = @uri[:webcm]
    params["sid"] = @sid
    response = @conn.post do |req|
      req.url @uri[:webcm]
      req.body = params
    end
  end

  # Collect fon configuration
  # @return [Hash] cfg
  # @todo rescue from Faraday::Error::TimeoutError
  def foncalls_cfg
    cfg = {}
    response = @conn.get do |req|
      req.url @uri[:settings]
      req.params['sid'] = @sid
      req.params['getpage'] = "../html/de/menus/menu2.html"
      req.params['var:pagename'] = 'foncalls'
      req.params['var:menu'] = 'fon'
    end
    doc = Nokogiri::HTML(response.body)
    elements = doc.xpath(select="//*[contains(@name,'cfg')]")
    elements.each do |e|
      cfg[e.attributes["name"].content] = e.attributes["value"].content
    end
    return cfg
  end

  #def get_settings()
  #  @pages = {
  #      "home" => ["home"],
  #      "internet" => ["inetstat", "pppoe", "userlist", "portfw", "overview"],
  #      "fon" => ["foncalls", "fonbuch", "wecker", "rulall", "routing", "fondevices", "siplist", "laender"],
  #      "net" => ["net", "status", "einstellungen"],
  #      "wlan" => ["common", "monitor", "encrypt2", "guest_access"],
  #      "dect" => ["settings"],
  #
  #      #"system" => ["syslog.lua", "energy.lua", "push.lua", "infoled.lua", "wlan_night.lua", "kenntwort.lua", "export.lua", "update.lua", "reboot.lua", "export.lua", "zeitzone", "sprache"]
  #
  #  }
  #end

  # Login to obtain the session-id
  # Initiate and set session if authentication was successful
  # @return [Boolean] true if authentication was successful
  #protected
  def login
    response = @conn.post do |req|
      req.url @uri[:login]
      req.body = { "response" => self.build_response }
    end

    if response.headers.include?("Location")
      @sid = URI.parse(response.headers["Location"]).query.gsub('sid=','')
    end

    return (@sid.nil?) ? false : true
  end

  # Obtain challenge ID
  protected
  def session_info
    @parser.parse(Nokogiri::XML(open("http://#{@hostname}#{@uri[:login_sid]}")).to_s)
  end

  # Create response String
  # for more information: http://www.avm.de/de/Extern/files/session_id/AVM_Technical_Note_-_Session_ID.pdf
  # @return [String] response
  protected
  def fritz_response(challenge)
    @md5magic = Digest::MD5.hexdigest(Iconv.conv('UTF-16LE', 'UTF-8', "#{challenge}-#{@password}"))
    @response = "#{challenge}-#{@md5magic}"
  end

  # Obtain challenge and create response
  # @see session_info
  # @see fritz_response
  # @return [String] response
  protected
  def build_response
    fritz_response(session_info["SessionInfo"]["Challenge"])
  end


  #  def enable_or_disable(telcfg)
  #  end
  #  alias_method :switch, :enable_or_disable

end