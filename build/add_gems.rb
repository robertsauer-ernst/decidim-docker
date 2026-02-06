File.open("Gemfile", "a") do |f|
  f.puts
  f.puts "gem \"pg\", \"~> 1.5\""
  f.puts "gem \"sidekiq\", \"~> 7.0\""
end
