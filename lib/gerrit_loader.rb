require 'json'
require 'uri'
require 'net/http'
require 'net/http/digest_auth'
require "base64"
require "yaml"

require 'pry'

class NotFoundError < StandardError; end

class Counts < Struct.new(:count, :sum, :date_range)
  def to_yaml
    [count, sum].join("-")
  end
  alias :to_s :to_yaml
end

# Configure for me!
AUTH_USER = "me"
AUTH_PASSWORD = "noWay"

BASE_URL = "https://gerrit.instructure.com"
JSON_HEADER = true ? "" : %Q|-H "Accept: application/json"|

# This is to use cached data instead of fetching it new....
# type = %w|details messages basic|
def get_data(type, change_id = nil)
  case type
  when "details"
  when "messages"
  when "basic"
  else
  end
end

def get_path(url, params=nil)
  system_call = "curl #{JSON_HEADER} --digest --user #{AUTH_USER}:#{AUTH_PASSWORD} #{BASE_URL}/a/#{url}"

  if params
    system_call << "--get "
    params.each do |param|
      system_call << "--data-urlencode #{param} "
    end
  end

  resp = %x| #{system_call} |
  begin
    raise NotFoundError if resp == "Not found\n"
  rescue
    $stderr.puts "#{system_call} got a terrible error"
  end

  begin
    JSON.parse(resp[5..-1])
  rescue JSON::ParserError
    resp
  end
end

# Return filtered messages
def filter_messages(messages=[])
  removed_ids = ["Jenkins","Firework"] # Jenkins and Firework
  return [] if messages.nil?
  messages.select do |message|
    message["author"].nil? ? false : !removed_ids.include?(message["author"]["name"]) || message["message"] == "stuff"
  end
end

# Pull out comment lengths and add them to the authors_hash
def measure_message_lengths_by_author(messages=[], authors_hash)
  return false if messages.nil?
  messages.each do |message|
    if message["author"]
      authors_hash[message["author"]["name"]] << message["message"].length
    end
  end
end

def author_count(change, hash)
  if change["owner"]
    hash[change["owner"]["name"]] += 1
  end
end

# Data OBJECTS
changes_hash = {}
authors_messages_scoreboard_hash = Hash.new {|h,k| h[k] = []}
author_commit_scoreboard_count_hash = Hash.new {|h,k| h[k] = 0 }

# get merged changes with all revisions
changes = get_path("changes/?q=status:merged&o=ALL_REVISIONS")  ## DOESN'T respect the &!!!!

changes.each do |change|
  change_id = change["change_id"]
  change = get_path("changes/#{change_id}/detail?o=ALL_REVISIONS")
  changes_hash[change_id] = change
  author_count(change, author_commit_scoreboard_count_hash)
  messages = change["messages"]
  # Use the messages to add to authors_messages_scoreboard_hash
  filtered = filter_messages(messages)
  measure_message_lengths_by_author(messages, authors_messages_scoreboard_hash)
  if change["revisions"]
    revisions = change["revisions"].keys
    revisions.each do |revision_id|
      # change = get_path("changes/#{change_id}/revisions/#{revision_id}/review")
    end
  end
end

counts_hash = {}
authors_messages_scoreboard_hash.each {|k,v| counts_hash[k] = Counts.new(v.count, v.inject(:+)) }


File.open("counts_and_sums.yml", "w") {|io| YAML.dump(counts_hash, io) }
File.open("basic_changes.yml", "w") {|io| YAML.dump(changes,io) }
File.open("changes_details.yml", "w") {|io| YAML.dump(changes_hash,io) }
File.open("messages.yml", "w") {|io| YAML.dump(authors_messages_scoreboard_hash,io) }
File.open("commit_count.csv","w") do |io| 
  author_commit_scoreboard_count_hash.each {|k,v| io.puts [k,v].join(",")}
end


binding.pry
=begin
digest_auth = Net::HTTP::DigestAuth.new
uri = URI.parse BASE_URL
uri.user = AUTH_USER
uri.password = AUTH_PASSWORD

h = Net::HTTP.new uri.host, uri.port

req = Net::HTTP::Get.new uri.request_uri, initheader = {'Content-Type' =>'application/json'}

p req
res = h.request req
# res is a 401 response with a WWW-Authenticate header


auth = digest_auth.auth_header uri, res['www-authenticate'], 'GET'

# create a new request with the Authorization header
req = Net::HTTP::Get.new uri.request_uri, initheader = {'Content-Type' =>'application/json'}
req.add_field 'Authorization', auth

# re-issue request with Authorization
res = h.request req


# Build the Authorization HEADER construct
AUTH_STRING = Base64.encode64("#{AUTH_USER}:#{AUTH_PASSWORD}")
AUTH_STRING = "cnRheWxvcjpCaWdiaWcuMjUu"
  {"Authorization" => "Basic #{AUTH_STRING}"}



HEADER = { "content-type" => "application/json",
  "Accept" => "application/json"
}

open(BASE_URL + "/projects/", HEADER) do |f|
  p f.base_uri
  p f.methods
end
=end