# frozen_string_literal: true

RSpec.describe 'streaming video load test', :load_test do
  let(:session_infos) do
    (1..Settings.load_test.streaming_video.multiplier).map do
      Settings.load_test.streaming_video.druids.map do |bare_druid|
        {
          bare_druid:,
          session: Capybara::Session.new(Capybara.default_driver)
        }
      end
    end.flatten
  end

  before do
    Capybara.configure do |config|
      config.threadsafe = true
    end
  end

  scenario do
    Parallel.each(session_infos) do |session_info|
      puts "#{session_info[:bare_druid]}: visiting PURL"
      session_info[:session].visit "#{Settings.purl_url}/#{session_info[:bare_druid]}"

      puts "#{session_info[:bare_druid]}: allowing page to load"
      sleep 30

      puts "#{session_info[:bare_druid]}: attempting to play video"
      expect(session_info[:session]).to have_css('button.vjs-big-play-button')
      session_info[:session].click_button("Play Video")

      puts "#{session_info[:bare_druid]}: sitting on page, trying to let video play"
      sleep Settings.load_test.streaming_video.watch_time
    end
  end
end
