# frozen_string_literal: true

require "amazing_print"

def show(run)
  puts "run"
  puts run.to_yaml
  puts "output:"
  ap $logoutput.string.lines.to_a.map { |x| x[/(?<=\] ).*/].strip }
  puts "status_log:"
  run.status_log.each { |e| ap e }
end

def check_output(logoutput, sample_out)
  sample_out = sample_out.lines.to_a.map { |x| x.strip }
  output = logoutput.string.lines.to_a.map { |x| x[/(?<=\] ).*/].strip }

  # puts "output:"
  # output.each {|l| puts l}

  expect(output.size).to eq sample_out.size
  output.each_with_index do |o, i|
    expect(o).to eq sample_out[i]
  end
end

def check_status_log(status_log, sample_status_log)

  # puts "status_log:"
  # status_log.each do |e|
  #   print "{ task: \"#{e[:task]}\", status: :#{e[:status]}"
  #   print ", progress: #{e[:progress]}" if e[:progress]
  #   print ", max: #{e[:max]}" if e[:max]
  #   puts " }"
  # end

  expect(status_log.size).to eq sample_status_log.size
  sample_status_log.each_with_index do |h, i|
    h.keys.each { |key| expect(status_log[i][key]).to eq h[key] }
  end
end
