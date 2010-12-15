module Babushka
  class BaseDepDefiner < DepDefiner
    include BaseDepRunner

    accepts_list_for :desc
    accepts_list_for :requires
    accepts_list_for :requires_when_unmet
    accepts_list_for :run_in
    accepts_block_for :internal_setup
    accepts_block_for :setup

    accepts_block_for :met?

    accepts_block_for :prepare

    accepts_block_for :before
    accepts_block_for :meet
    accepts_block_for :after

    def pkg_manager
      BaseHelper
    end

    private

    def chooser
      Base.host.match_list
    end

    def chooser_choices
      Base.host.all_tokens
    end

  end
end
