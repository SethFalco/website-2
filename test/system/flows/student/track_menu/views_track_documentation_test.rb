require "application_system_test_case"
require_relative "../../../../support/capybara_helpers"

module Flows
  module Student
    module TrackMenu
      class ViewsTrackDocumentationTest < ApplicationSystemTestCase
        include CapybaraHelpers

        test "student views track documentation" do
          user = create :user
          track = create :track, title: "Ruby"
          create(:concept_exercise, track:)
          create(:user_track, user:, track:)

          stub_latest_track_forum_threads(track)

          use_capybara_host do
            sign_in!(user)
            visit track_url(track)
            click_on "Track options"

            assert_link "Ruby documentation", href: track_docs_url(track)
          end
        end
      end
    end
  end
end
