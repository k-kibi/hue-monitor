class HueMeetingRoomJob < ApplicationJob
  queue_as :default

  DEFAULT_HSB = {
    hue: 14922,
    saturation: 144,
    brightness: 254
  }

  # 会議室の予定を参照してhueを光らせる
  # @param [String] type
  def perform(type)
    case type
    when 'warn'
      # 次の予定あり
      hue_warn RGB.new(228, 248, 255).to_hue
    when 'notice'
      # 次の予定なし(白)
      hue_notice RGB.new(128, 128, 128).to_hue
    when 'default'
      # 元の色に戻す
      back_to_normal
    end
  end

  # 次の予定があることを知らせる光らせ方
  # @param [Hash] hsb
  def hue_warn(hsb)
    client = Hue::Client.new
    lights = client.lights

    state_on = { on: true }.merge hsb
    hsb_dark = DEFAULT_HSB.dup
    hsb_dark[:brightness] = (hsb_dark[:brightness] * 0.6).to_i
    state_off = { on: true }.merge hsb_dark
    state_default = { on: true }.merge DEFAULT_HSB

    lights.each do |light|
      light.set_state state_on, 20
    end
  end

  # 次の予定がないことを知らせる光らせ方
  # @param [Hash] hsb
  def hue_notice(hsb)
    client = Hue::Client.new
    lights = client.lights

    state_on = { on: true }.merge hsb
    state_default = { on: true }.merge DEFAULT_HSB

    1.times do
      lights[0].set_state state_on, 3
      sleep 0.5
      lights[0].set_state state_off, 5
      lights[2].set_state state_on, 3
      sleep 0.5
      lights[0].set_state state_default, 10
      lights[1].set_state state_on, 3
      lights[2].set_state state_off, 5
      sleep 0.5
      lights[1].set_state state_off, 5
      lights[2].set_state state_default, 10
      sleep 0.5
      lights[1].set_state state_default, 10
    end
  end

  # 元の光色に戻す
  def back_to_normal
    client = Hue::Client.new
    lights = client.lights

    state_default = { on: true }.merge DEFAULT_HSB
    lights.each do |light|
      light.set_state state_default, 5
    end
  end
end
