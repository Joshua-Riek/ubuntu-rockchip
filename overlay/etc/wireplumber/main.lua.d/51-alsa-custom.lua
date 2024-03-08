rule = {
    matches = {
      {
        { "device.name", "matches", "alsa_card.platform-hdmi0-sound" },
      },
    },
    apply_properties = {
        ["device.description"] = "HDMI0",
    },
  }
  table.insert(alsa_monitor.rules,rule)

rule = {
    matches = {
      {
        { "device.name", "matches", "alsa_card.platform-hdmi1-sound" },
      },
    },
    apply_properties = {
        ["device.description"] = "HDMI1",
    },
  }
  table.insert(alsa_monitor.rules,rule)

rule = {
    matches = {
      {
        { "device.name", "matches", "alsa_card.platform-hdmiin-sound" },
      },
    },
    apply_properties = {
        ["device.description"] = "HDMI",
    },
  }
  table.insert(alsa_monitor.rules,rule)

rule = {
    matches = {
      {
        { "device.name", "matches", "alsa_card.platform-dp0-sound" },
      },
    },
    apply_properties = {
        ["device.description"] = "DP0",
    },
  }
  table.insert(alsa_monitor.rules,rule)

rule = {
    matches = {
      {
        { "device.name", "matches", "alsa_card.platform-dp1-sound" },
      },
    },
    apply_properties = {
        ["device.description"] = "DP1",
    },
  }
  table.insert(alsa_monitor.rules,rule)

rule = {
    matches = {
      {
        { "device.name", "matches", "alsa_card.platform-es8388-sound" },
      },
    },
    apply_properties = {
        ["device.description"] = "ES8388",
    },
  }
  table.insert(alsa_monitor.rules,rule)

rule = {
    matches = {
      {
        { "device.name", "matches", "alsa_card.platform-rt5616-sound" },
      },
    },
    apply_properties = {
        ["device.description"] = "RT5616",
    },
  }
  table.insert(alsa_monitor.rules,rule)
