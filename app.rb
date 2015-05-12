require 'sinatra'
require 'openssl'
require 'json'
require "sinatra/config_file"

config_file 'settings.yml'

get '/' do
  'Hello world!'
end

post '/' do
  if check_github_signature
    @payload = JSON.parse params["payload"]

    if @payload["ref"]
      @branch = @payload["ref"].split('/').last
    else
      @branch = 'master'
    end

    if @payload["commits"]
      @affect_files = @payload["commits"].inject([]) do |r, commit|
        r = r + commit["added"] + commit["removed"] + commit["modified"]
        r
      end
    else
      @affect_files = []
    end

    if deploy?
      if should_complete_deploy?
        complete_deploy
      else
        partical_deploy
      end
    end

  end
end

module HookUtils
  def check_github_signature
    origin_signature = request.env["HTTP_X_HUB_SIGNATURE"]
    return true unless origin_signature
    secret = settings.github_webhook_secret
    h = OpenSSL::Digest::Digest.new('sha1')
    body = request.body.read
    target_signature = OpenSSL::HMAC.hexdigest(h, secret, body)
    origin_signature == "sha1=#{target_signature}"
  end

  def deploy?
    @payload["repository"]["full_name"]==settings.github_repository_fullname and settings.github_branchs.include?(@branch)
  end

  def should_complete_deploy?
    assets_ext = %w(.css .scss .js .coffee .jpg .png .gif .jpeg)
    @affect_files.any? do |file|
      assets_ext.include? File.extname(file)
    end
  end

  def complete_deploy
    p "complete_deploy"
    p "cd #{settings.deploy_path}"
    p "cap #{settings.deploy_env} deploy"
  end

  def partical_deploy
    p "partical_deploy"
    p "cd #{settings.deploy_path}"
    p "NO_RESTART=true FILES=#{@affect_files.join(',')} cap #{settings.deploy_env} deploy:upload deploy:restart"
  end
end

helpers HookUtils
