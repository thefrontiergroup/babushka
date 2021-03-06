dep 'ruby' do
  met? {
    provided? 'ruby >= 1.8.6'
  }
  requires_when_unmet {
    on :osx, 'ruby.external'
    on :ubuntu, 'ruby.managed'
  }
end

dep 'ruby.managed' do
  installs {
    on :maverick, %w[ruby ruby1.8-dev]
    via :apt, %w[ruby irb ruby1.8-dev libopenssl-ruby]
  }
  provides %w[ruby irb]
end

dep 'ruby.external' do
  expects 'ruby >= 1.8.6', 'irb'
  otherwise { log_error "This system should already have ruby on it." }
end
