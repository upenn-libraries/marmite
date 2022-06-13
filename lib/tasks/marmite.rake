namespace :marmite do
  desc 'Start development/test environment'
  task :start do
    system('lando start')

    # Sleeping to ensure MySQL container is up.
    # TODO: Should find a better solution.
    sleep(5)

    # Create databases, if they aren't present.
    system('bundle exec rake db:create')

    # Migrate test and development databases
    system('RACK_ENV=development bundle exec rake db:migrate')
    system('RACK_ENV=test bundle exec rake db:migrate')
  end

  desc 'Stop development/test environment'
  task :stop do
    system('lando stop')
  end

  desc 'Cleans development/test environment'
  task :clean do
    system('lando destroy -y')
  end
end
