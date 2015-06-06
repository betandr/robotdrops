require 'launchpad'

interaction = Launchpad::Interaction.new(:device_name => "Launchpad S")

@home_path = "/Users/beth/Projects/robotdrops/clips"

@clip_pids = Array.new
@clips = Array.new
@clip_paths = Array.new

def get_audio_clips
     p "seeking in #{@home_path} for wavs"
     paths = Dir["#{@home_path}/**/*.wav"]

     paths.each do |path|
         index = path.gsub("#{@home_path}/", "").gsub(".wav", "")
         @clips << index
     end

     p "loaded #{@clips.length} clips"
end

def play(row, column)
    clip = "#{@home_path}/#{row}_#{column}.wav"
    p "triggering #{clip}"

    if (!is_clip(row, column))
        stop_other_audio
        pid = fork{ exec "play #{clip} repeat 99" }
        @clip_pids << pid
    else
        pid = fork{ exec "play #{clip}" }
    end
end

def is_clip(row, column)
    clip = false

    if (column == 7)
        if ((row == 5) || (row == 6) || (row == 7))
            clip = true
        end
    end

    clip
end

def stop_other_audio
    @clip_pids.each do |pid|
        p "stopping #{pid}"
        Process.kill "TERM", pid
        Process.wait pid
    end

    @clip_pids = Array.new
end

def brightness(action)
  action[:state] == :down ? :off : :high
end

# grid buttons
interaction.response_to(:grid) do |interaction, action|
  b = brightness action

  if (action[:state] == :down ) then
      play action[:x], action[:y]
  end

  if (action[:state] == :up ) then
      interaction.device.change :grid, action.merge(:green => b, :red => b)
  end
end

# top control buttons
interaction.response_to([:up, :down, :left, :right, :session, :user1, :user2, :mixer]) do |interaction, action|
  interaction.device.change action[:type], :red => brightness(action)
end

# scene buttons
interaction.response_to([:scene1, :scene2, :scene3, :scene4, :scene5, :scene6, :scene7, :scene8]) do |interaction, action|
  interaction.device.change action[:type], :green => brightness(action)
end

# mixer button terminates interaction on button up
interaction.response_to(:mixer, :up) do |interaction, action|
  interaction.stop
end

def button_has_clip?(row, column)
    @clips.include? "#{row}_#{column}"
end

#get all clips
get_audio_clips

(0..7).each do |x|
    (0..7).each do |y|
        if (button_has_clip? x, y) then
            interaction.device.change :grid, :x => x, :y => y, :red => :low, :green => :high
        else
            interaction.device.change :grid, :x => x, :y => y, :red => :high, :green => :low
        end
    end
end

# start interacting
interaction.start

# sleep so that the messages can be sent before the program terminates
sleep 0.1
