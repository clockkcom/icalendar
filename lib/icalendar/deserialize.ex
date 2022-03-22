defprotocol ICalendar.Deserialize do
  def from_ics(ics)
end

alias ICalendar.Deserialize

defimpl ICalendar.Deserialize, for: BitString do
  alias ICalendar.Util.Deserialize

  def from_ics(ics) do
    ics
    |> String.trim()
    # VALARMs are overwriting the event's actual description and summary, simply ignore anything between these two markers
    |> String.replace(~r/BEGIN\:VALARM[\s\S]*?END:VALARM/, "")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> get_events()
  end

  defp get_events(calendar_data, event_collector \\ [], temp_collector \\ [])

  defp get_events([head | calendar_data], event_collector, temp_collector) do
    case head do
      "BEGIN:VEVENT" ->
        # start collecting event
        get_events(calendar_data, event_collector, [head])

      "END:VEVENT" ->
        # finish collecting event
        event =
          case event_is_after_epoch(temp_collector) do
            false ->
              []

            true ->
              [Deserialize.build_event(temp_collector ++ [head])]
          end

        get_events(calendar_data, event ++ event_collector, [])

      event_property when temp_collector != [] ->
        get_events(calendar_data, event_collector, temp_collector ++ [event_property])

      _unimportant_stuff ->
        get_events(calendar_data, event_collector, temp_collector)
    end
  end

  defp event_is_after_epoch(event) do
    date_is_valid(event, "DTSTART") and date_is_valid(event, "DTEND")
  end

  defp date_is_valid(event, dateproperty) do
    valid =
      case Enum.find(event, fn property ->
             String.contains?(property, dateproperty)
           end) do
        nil ->
          # this is an invalid event, ignore
          false

        string ->
          # we found a date, see if it's too old
          case Regex.match?(~r/19[0-6]\d{4}/, string) do
            true ->
              # date is before 1970, ignore
              false

            false ->
              # date is after 1970, ignore
              true
          end
      end
  end

  defp get_events([], event_collector, _temp_collector), do: event_collector
end
