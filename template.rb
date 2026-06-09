# app_template.rb

# Add gems or custom configurations if needed

gem_group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "ruby-lsp-rspec", require: false
end

# Run bundle install after adding gems
after_bundle do
  say "configure extensions and vscode settings"

  insert_into_file '.devcontainer/devcontainer.json', after: "  // \"customizations\": {},\n" do <<~JSON
    "customizations": {
		"vscode": {
			"settings": {
        "editor.tabSize": 2,
			},
			"extensions": [
				"stripe.endsmart",
				"KoichiSasada.vscode-rdbg",
        "GitHub.copilot",
        "GitHub.copilot-chat",
        "oderwat.indent-rainbow",
        "redhat.vscode-yaml"
			]
		}
	},
  JSON
  end

  say "setup up rspec"
  generate "rspec:install"

  file 'spec/support/factory_bot.rb' do <<~RUBY
    FactoryBot.definition_file_paths = [ "RSpec.root.join('spec', 'factories')" ]

    RSpec.configure do |config|
      config.include FactoryBot::Syntax::Methods
    end
  RUBY
  end


  inject_into_file 'spec/rails_helper.rb' do <<-'RUBY'
    require_relative 'support/factory_bot'
  RUBY
  end

  inject_into_file 'config/application.rb', after: "class Application < Rails::Application\n" do <<-'RUBY'
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  RUBY
  end

  FileUtils.rm_rf 'test'

  say "setting up UUIDs"

  generate "migration EnableUuidExtension"

  inject_into_file Dir['db/migrate/*_enable_uuid_extension.rb'].first, after: "def change\n" do <<-'RUBY'
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
  RUBY
  end

  rails_command "db:migrate"

  # Set default primary key type to UUID in config/application.rb
  inject_into_file "config/application.rb", after: "class Application < Rails::Application\n" do <<-'RUBY'
    # Use UUIDs as the default primary key type
    config.active_record.primary_key = :uuid
  RUBY
  end

  say "creating launch.json for debugging"

  file '.vscode/launch.json' do <<~JSON
    {
      // Use IntelliSense to learn about possible attributes.
      // Hover to view descriptions of existing attributes.
      // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
      "version": "0.2.0",
      "configurations": [
        {
          "name": "Debug Rails Server",
          "type": "ruby_lsp",
          "request": "launch",
          "program": "rails server",
        },
        {
          "name": "Debug RSpec Tests",
          "type": "ruby_lsp",
          "request": "launch",
          "program": "rspec ${relativeFile}:${lineNumber}",
        }
      ]
    }
  JSON
  end

  say 'cleaning up'
  run "rubocop -A"
  run "git config core.fileMode false"
  run "git add ."
  run "git commit -m 'Initial commit'"
end
