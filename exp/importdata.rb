require File.dirname(__FILE__) + '/../boot'
require 'fastercsv'
Rametook::Utility.load_rails_environment

FasterCSV.foreach("in.csv") do |row|
  
  ModemErrorMessage.create(
    :err_type => 'access_failure',
    :code => row[0].hex,
    :message => row[1])
end
