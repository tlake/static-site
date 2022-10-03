---
draft: false
title: "Streaming to Discord on Linux: Managing audio streams via PulseAudio"
date: 2022-10-02T18:00:00-07:00
toc: true,
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

### - Commands

```zsh
# create sink "vs-broadcast"
pactl load-module module-null-sink sink_name=vs-broadcast sink_properties=device.description=vs-broadcast

# create sink "vs-splitter"
pactl load-module module-null-sink sink_name=vs-splitter sink_properties=device.description=vs-splitter

# connect microphone to vs-broadcast
pactl load-module module-loopback source_dont_move=1 source=alsa_input.usb-SteelSeries_SteelSeries_Arctis_5_00000000-00.analog-chat sink=vs-broadcast

# connect vs-splitter to vs-broadcast
# note that a virtual sink's source address is sinkname.monitor
pactl load-module module-loopback source_dont_move=1 source=vs-splitter.monitor sink=vs-broadcast

# connect vs-splitter to headphones
# note that a virtual sink's source address is sinkname.monitor
pactl load-module module-loopback source_dont_move=1 source=vs-splitter.monitor sink=alsa_output.usb-SteelSeries_SteelSeries_Arctis_5_00000000-00.analog-chat
```

## Complication 1: Discord and noise reduction

![Figure 03: The system with preprocessing via PulseEffects](/images/blog/discord-fig-03.png)

### - What luck, a visualizer

![Graph 00: The first completed version, as visualized by pagraphcontrol](/images/blog/discord-graph-00.png)

## Complication 2: No game audio when game window isn't active

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

![Graph 01: The second completed version, as visualized by pagraphcontrol](/images/blog/discord-graph-01.png)
