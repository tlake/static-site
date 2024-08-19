---

date: 2022-10-02T21:00:00-08:00
draft: false
tags: [
    "bash",
    "discord",
    "linux",
    "mint",
    "No Man's Sky",
    "pacmd",
    "pactl",
    "pagraphcontrol",
    "pulseaudio",
    "pulseeffects",
    "stream",
    "streaming",
]
title: "Streaming to Discord on Linux: Managing audio streams via PulseAudio"
url: /blog/streaming-to-discord-on-linux-managing-audio-streams-via-pulseaudio

---

As it turns out, streaming game audio to Discord isn't trivial when you're on Linux.

## The Problem

It seems like Discord's "Go Live" feature, which allows streaming both application audio and application video in addition to voice chat, doesn't really exist on Linux? This means that I could share the visuals of a game that I'm playing and speak with friends in a Discord voice channel, but I couldn't also send the game audio across Discord to my friends who were tuning in.

![Figure 00: The system as Discord allows it](/images/blog/discord-fig-00.png)

At a base level, what I wanted was to be able to send the game audio both to Discord and to my own headphones:

![Figure 01: The system as I originally imaginined it](/images/blog/discord-fig-01.png)

As an alternative, I could have streamed on something like Twitch, but then I'd have to worry about internet randos and OBS Studio, so instead I figured it would be nice to burn a whole weekend getting into the introductory weeds of audio engineering.

## Designing the System

The first resource that really started getting me anywhere was [this 2016 blog post by Emma Joe Anderson](https://endless.ersoft.org/pulseaudio-loopback/). This post gave me the introduction I needed in terms of devices vs sinks and how to conceptually wire things together with PulseAudio:

> _Devices_ are physical audio hardware like microphones, headphones, and speakers. _Virtual sinks_ are virtual devices. Pulseaudio by default connects each non-device to exactly one device. To connect two non-devices together, a virtual sink must be used. To connect two devices together, a _loopback_ must be used. A loopback has exactly one input and one output, but a device may have as many loopbacks going in and out of it as desired.

So, following that post as a guide, I identified all the hardware devices in this system (my microphone, and my headphones), and then created virtual sinks for items which were _not_ proper devices. In my case, I needed to create 2 virtual sinks: one to represent the device that would be sent to Discord, and one to represent the game (or really, any application) audio.

After identifying my virtual sinks, I needed to identify the loopbacks - the device-to-device connections - I'd need to create. These would be: one between the microphone device and the Discord sink; one between the application sink and the Discord sink; and one between the application sink and the headphones device.

![Figure 02: The system with virtual sinks and loopbacks](/images/blog/discord-fig-02.png)

Note that the "application", "discord input", and "discord output" items aren't devices, so they don't need loopbacks in order to connect them to other devices.

## Implementing the Design

With my system visualized, it was time to learn some `pactl` commands and actually create these resources. Again, Emma's post was a very helpful starting point here, as it listed the commands needed to create their own desired system:

> ```zsh
> pactl load-module module-null-sink sink_name=Virtual1
> pactl load-module module-null-sink sink_name=Virtual2
> pactl load-module module-loopback sink=Virtual1
> pactl load-module module-loopback sink=Virtual1
> pactl load-module module-loopback sink=Virtual1
> ```
>
> For each loopback, name the sink that should be its input, or at least one that isn't what you will make the output.

Mine wasn't very different from theirs, so a little copypasta later and I was mostly in business! What came next was making sure that the arrows in the diagram were accurately reflected in the system - of course, they weren't, and it took some doing to understand just what needed to happen. The end of Emma's post contained a video where they stepped through their process, but I had some trouble keeping everything straight; despite passing "`sink_name=`" the sinks all displayed as "Null Output" in the `pavucontrol` window and it was difficult telling which was which.

I decided to do a bit of a deeper dive into `pactl load-module` and the modules I was using, to see if there was any kind of sane way to differentiate my custom sinks. [Documentation on freedesktop.org](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/Modules/#devicedrivermodules) keyed me into the `device.description` property common to sink arguments, so I now had a way to name my sinks. And for the `module-loopback` argument, I learned about `source_dont_move=1` to prevent a loopback's source from jumping around, and that in addition to setting `sink=` I can also set `source=` in the command, so I wouldn't need to fuss with the `pavucontrol` GUI to try and set my arrows.

I decided to name my out-to-Discord sink `"vs-broadcast"` and my in-from-application sink `"vs-splitter"`. I then had to do some investigating with `pactl list` in order to figure out the correct names for my microphone and headphones devices, but once I had them, it was time to construct my commands and run 'em!

### Commands

```zsh
# create sink "vs-broadcast"
pactl load-module module-null-sink sink_name=vs-broadcast sink_properties=device.description=vs-broadcast

# create sink "vs-splitter"
pactl load-module module-null-sink sink_name=vs-splitter sink_properties=device.description=vs-splitter

# connect microphone to vs-broadcast
pactl load-module module-loopback source_dont_move=1 source=alsa_input.usb-SteelSeries_SteelSeries_Arctis_5_00000000-00.analog-chat sink=vs-broadcast latency_msec=1

# connect vs-splitter to vs-broadcast
# note that a virtual sink's source address is sinkname.monitor
pactl load-module module-loopback source_dont_move=1 source=vs-splitter.monitor sink=vs-broadcast latency_msec=1

# connect vs-splitter to headphones
# note that a virtual sink's source address is sinkname.monitor
pactl load-module module-loopback source_dont_move=1 source=vs-splitter.monitor sink=alsa_output.usb-SteelSeries_SteelSeries_Arctis_5_00000000-00.analog-chat latency_msec=1
```

_Edit 2024-01-04: Added `latency_msec` flags to loopback creation commands. This solves a problem when the default command — or the creation executed in the `pagraphcontrol` gui — introduces delay to the audio chain._

## Complication 1: Discord and noise reduction

The system was working! I could pipe my application audio to Discord along with my voice, and to my headphones along with my friends' voices! I was testing my setup by using a music player for the application, and that's when I noticed that Discord was filtering out parts of the music just like it would do for my voice. This was a problem, because it meant that I wouldn't be able to broadcast application audio at a low level relative to my voice, which meant that anyone listening would be struggling with hearing me over the application. But if I cranked Discord's input sensitivity setting way down so that it could pick up the quieter application audio, it would _also_ pick up all the annoying background noises coming into my microphone!

I had no choice - I would have to take the processing of my voice away from Discord and handle it myself.

Enter PulseEffects - or rather, I guess it's called Easy Effects these days? In any event, it's a software EQ-and-effects application, and one of its features is a noise gate effect that I should be able to use in order to cut out some of the background noises from my mic before I send it into the vs-broadcast sink.

![Figure 03: The system with preprocessing via PulseEffects](/images/blog/discord-fig-03.png)

PulseEffects creates several virtual sinks of its own, and at this point it was starting to become difficult again to keep track of all the devices and their connections, even though I had my diagrams and even though the devices and sinks in `pavucontrol` were named different, recognizable things. I began wishing for a graphical way to configure these settings, and I found one!

### What luck, a graphical editor!

I came across the [pagraphcontrol github repo](https://github.com/futpib/pagraphcontrol), and while there doesn't seem to be a PPA for my distro (I'm running Linux Mint 20.2 at the time of this writing), it was easy to clone down the repo and install/build/run the project with `yarn`.

Then, after a little trial and error with all the new items that PulseEffects added to my system, I was able to connect the right boxes with the right arrows to get a system that was working!

![Graph 00: The first completed version, as visualized by pagraphcontrol](/images/blog/discord-graph-00.png)

_**Note 1:** I still don't fully understand the resources that PulseEffects creates. It has a section for applying effects to application-like outputs and a section for applying effects to microphone-like inputs, and each of these sections seems to create a familiar-looking virtual sink setup. However, each section **also** creates a pair of objects sporting the PulseEffects icon, and there's no visual way to distinguish between them except that some of them can accept an input and the others can output to devices. Furthermore, as seen in the diagram, there's no visible connecting arrow between the input and output of a PulseEffects pair, which can make it difficult to keep track of everything._

_My best understanding at the moment is that the icon-input "device" collects input streams and pipes them into the PulseEffects application so that it can do work applying effects. The end result seems to be piped out through the icon-output object, which must send to the virtual "PulseEffects(mic)" sink. Now we're back in familiar territory, as I can grab the output of that sink (or rather, its monitor) with a loopback in order to send it off to some other device._

_**Note 2:** In the above diagram, you may notice that I'm sending the "PulseEffects(mic)" into the "vs-splitter" (shown as "Splitter") sink instead of to the "vs-broadcast" (shown as "OutForBroadcast") sink as originally intended. By doing so, I'm able to send my voice out to Discord as well as to my headphones, so that I can hear the results of messing with the effects. This is only for testing purposes, and once I've got my mic stream sounding the way I want, I would change the loopback to connect "PulseEffects(mic)" instead to "vs-broadcast"._

I won't pretend that I know what I'm doing with PulseEffects yet, but at least the audio routes properly now.

## Complication 2: No game audio when game window isn't active

This is a problem with No Man's Sky in particular: when you alt+tab out of NMS (or take some other action that results in the NMS game window not being the active window), the game pauses. Or maybe not _fully_ pauses, there seems to be some debate about whether or not it pauses in multiplayer, but regardless, the audio stops playing when the game window isn't the active window.

This makes it incredibly frustrating to try and change the pathing of the audio, since there's no representation of the audio stream that exists in the system unless the audio is actively playing. If I put NMS in windowed mode and open pagraphcontrol beside it, I can see an audio device-or-stream appear when I make NMS the active window. Unfortunately, by default the game doesn't send to my vs-splitter sink, so the game audio doesn't go out to Discord. For any other application, I could just drag the arrow in pagraphcontrol to the correct sink, or hit up the terminal and use `pactl move-sink-input` to do the same thing - except with NMS, as soon as I enter the pagraphcontrol or my terminal, the NMS window becomes unfocused and stops playing audio, which causes its device to no longer exist for these other appliations to target them.

So then I wanted to write a quick little bash script that could run in the background and perform that `pactl move-sink-input` - unfortunately, this command requires the index of the sink and not some sort of human-readable name; even more unfortunately, `pactl list-sink-inputs` is more human-readable than programmatic, so parsing out the index of a sink input is not straightforward.

Luckily, [this parsing problem was solved a couple years ago on stackoverflow](https://stackoverflow.com/questions/39736580/look-up-pulseaudio-sink-input-index-by-property), so I was able to lift the perl regex and awk filtering from there. I ran into a bit of a problem trying to account for the apostrophe in the name "No Man's Sky" which turned out to be a problem because the awk regex also needs to be in single quotes it seems, so instead of trying to find the right combination of escapes and special characters, I just changed the substring search to `*"No Man"*`.

With the script working, all I needed to do was get it to run while the game was playing. I didn't want to keep it running forever in the background (and it seems I don't have to - after switching it once, it seems to stay configured that way), so I just wrapped the script execution command in a quick for-loop that iterated just a handful of times, kicked it off, and switched into NMS before the loop was finished iterating.

```bash
#!/bin/bash

################
# README
# 1. Set up all the PulseAudio sinks and loopbacks, such that a sink 'vs-splitter' is going
#    out to both a broadcast sink and to your desired headphones playback.
# 2. Get No Man's Sky running.
# 3. Run something like `for x in {0..4} ; do sleep 2 ; ./remap-nomansky-sink-input-to-vs-splitter.bash ; done`
#    Then, before the loop terminates, switch to the No Man's Sky window so that its audio is playing.
#    This script should pick up the No Man's Sky sink and redirect it to the vs-splitter sink.
#    In theory, it should then stay that way across multiple window defocusing events.

name="No Man"
inputs=$(pacmd list-sink-inputs |
    tr '\n' '\r' |
    perl -pe 's/.*? *index: ([0-9]+).+?application\.name = "([^\r]+)"\r.+?(?=index:|$)/\2:\1\r/g' |
    tr '\r' '\n')

echo "inputs:"
echo "${inputs}"

if [[ "$inputs" == *"${name}"* ]] ; then
    echo "found something in the inputs"
    index=$(echo "${inputs}" | awk -F ":" '/'"${name}"'/ {print $2}')
    echo $index
    pactl move-sink-input ${index} "vs-splitter"
fi
```

Finally the system seems to be working as intended! The extra arrows on the following diagram are just visual glitches caused by trying to drag the NMS device up to group with Spotify in the tiny window of time between clicking out of NMS and the audio stopping.

![Graph 01: The second completed version, as visualized by pagraphcontrol](/images/blog/discord-graph-01.png)
