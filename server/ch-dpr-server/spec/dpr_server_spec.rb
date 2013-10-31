require 'rspec'
require 'rack/test'
require_relative '../dpr_server'

SMALL  = IO.read('assets/photo-1.0x.jpg').size
MEDIUM = IO.read('assets/photo-1.5x.jpg').size
LARGE  = IO.read('assets/photo-2.0x.jpg').size

describe 'Client-Hints image server' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  context 'GET {name} without CH-DPR hint' do
    it 'should return 400 on missing file' do
      get '/missing.jpg'
      last_response.status.should eq 400
    end

    it 'may return low-res asset if filename is just the name' do
      get '/photo.jpg'
      last_response.body.size.should eq SMALL
    end

    it 'may return exact asset if filename is an exact match' do
      get '/photo-453-1.5x.jpg'
      last_response.body.size.should eq MEDIUM
    end
  end

  context 'GET {name} with CH-DPR hint' do
    before(:each) do
      get '/photo.jpg', {}, {'HTTP_CH_DPR' => 2.2}
    end

    it 'should round down to closest available DPR breakpoint' do
      last_response.body.size.should eq LARGE
    end

    it 'should confirm selected asset via DPR header' do
      last_response.headers['DPR'].should eq '2.0'
    end

    it 'should return Vary: DPR header' do
      last_response.headers['Vary'].should match('DPR')
    end

    it 'should allow force_dpr query string override' do
      get '/photo.jpg', {}, {
        'HTTP_CH_DPR' => 2.2,
        'QUERY_STRING' => 'force_dpr=1.8'
      }

      last_response.body.size.should eq MEDIUM
      last_response.headers['DPR'].should eq '1.5'
    end
  end
end
