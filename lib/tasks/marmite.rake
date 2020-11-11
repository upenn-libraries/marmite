namespace :marmite do
  desc 'Start development/test environment'
  task :start do
    system('lando start')

    # Create databases, if they aren't present.
    system('rake db:create')

    # Migrate test and development databases
    system('RACK_ENV=development rake db:migrate')
    system('RACK_ENV=test rake db:migrate')
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
