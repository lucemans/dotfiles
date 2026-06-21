lutils = require ("linking-utils")
cutils = require ("common-utils")
log = Log.open_topic ("s-spotify-routing")

SimpleEventHook {
  name = "linking/find-spotify-target",
  before = "linking/find-defined-target",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-target" },
    },
  },
  execute = function (event)
    local _, om, si, si_props, _, target = lutils:unwrap_select_target_event (event)

    if target then
      return
    end

    if si_props ["application.name"] ~= "spotify" and si_props ["node.name"] ~= "spotify" then
      return
    end

    local target_direction = cutils.getTargetDirection (si_props)

    for lnkbl in om:iterate {
      type = "SiLinkable",
      Constraint { "item.node.direction", "=", target_direction },
    } do
      local target_props = lnkbl.properties
      local target_name = target_props ["node.name"] or ""
      local target_description = target_props ["node.description"] or ""

      if target_description == "Scarlett 18i20 3rd Gen Line Output 5+6" or
          target_name == "scarlett-5+6" or
          target_name == "alsa_output.usb-Focusrite_Scarlett_18i20_USB_P9XHP15281198F-00.HiFi__Line5__sink" then
        if lutils.canLink (si_props, lnkbl) then
          log:info (si, "routing Spotify to " .. target_name)
          event:set_data ("target", lnkbl)
        end
        return
      end
    end
  end,
}:register ()
