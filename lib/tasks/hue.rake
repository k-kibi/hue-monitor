namespace :hue do
  desc 'Hueの動作スケジュールを入れる'
  task put_schedule: :environment do
    connection = Faraday.new(Cybozu.base_url) do |builder|
      builder.request(:url_encoded)
      builder.use(:cookie_jar)
      builder.options.params_encoder = Faraday::FlatParamsEncoder
      builder.adapter(Faraday.default_adapter)
    end
    Cybozu.login(connection)

    now = Time.now
    today = now.strftime '%Y.%-m.%-d'
    url = "https://xtone.cybozu.com/o/ag.cgi?page=ScheduleUserDay&GID=f&UID=&Date=da.#{today}"
    res = connection.get url
    html = res.body.force_encoding 'UTF-8'
    doc = Nokogiri.HTML html

    selector = "div.dnd-item"
    exit if doc.search(selector).size == 0

    cb_pattern1 = /dt\.(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)/
    cb_pattern2 = /tm\.(\d+)\.(\d+)\.(\d+)/

    start_times = []
    end_times = []

    doc.search(selector).each do |div|
      # 開始時間
      md = div.get_attribute('data-cb-st').match(cb_pattern1).to_a
      if md.size == 0
        md = div.get_attribute('data-cb-st').match(cb_pattern2).to_a
        next if md.size == 0
        start_time = Time.local(now.year, now.month, now.day, *md.values_at(1..3))
      else
        start_time = Time.local(*md.values_at(1..6))
      end

      # 終了時間
      md = div.get_attribute('data-cb-et').match(cb_pattern1).to_a
      if md.size == 0
        md = div.get_attribute('data-cb-et').match(cb_pattern2).to_a
        next if md.size == 0
        end_time = Time.local(now.year, now.month, now.day, *md.values_at(1..3))
      else
        end_time = Time.local(*md.values_at(1..6))
      end

      start_times << start_time
      end_times << end_time
    end

    # --------------------
    # 現在から1時間先までの会議室使用予定を確認し、
    # 「会議が始まる10分前(強)」と「会議が終わる10分前(弱)」にお知らせをする。
    # 上記２つが同じ時間になる場合は、「会議が始まるお知らせ」を優先する
    # --------------------

    schedules = []
    start_times.each do |start_time|
      next if start_time < now || start_time - now > 60*60

      # 予定開始時に照明をリセット
      HueMeetingRoomJob.set(wait_until: start_time).perform_later(:default)

      target_time = start_time - 60*10
      schedules << target_time
      p "Perform warn at #{target_time.strftime '%Y-%m-%d %H:%M:%S'}"
      HueMeetingRoomJob.set(wait_unitl: target_time).perform_later(:warn)
    end

    end_times.each do |end_time|
      next if end_time < now || end_time - now > 60*60

      target_time = end_time - 60*10
      next if schedules.any? { |time| (time <=> target_time) == 0 }
      schedules << target_time
      p "Perform notice at #{target_time.strftime '%Y-%m-%d %H:%M:%S'}"
      HueMeetingRoomJob.set(wait_until: target_time).perform_later(:notice)
    end
  end
end
