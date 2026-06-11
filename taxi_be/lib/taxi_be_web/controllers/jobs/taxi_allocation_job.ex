defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :start, [:nosuspend])
    {:ok, %{
      request: request,
      taxis: [],
      accepted_taxi: nil,
      rejected: MapSet.new(),
      timer: nil,
      eta_seconds: nil,
      accepted_at: nil
    }}
  end

  def handle_info(:start, %{request: request} = state) do
    fare = Enum.random([70, 75, 80, 85, 90, 95])
    %{"username" => customer} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
      %{msg: "The ride will have a cost of #{fare} pesos"})

    taxis = candidate_taxis()

    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address,
      "booking_id" => booking_id
    } = request

    Enum.each(taxis, fn taxi ->
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> taxi.nickname,
        "booking_request",
        %{msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'", bookingId: booking_id}
      )
    end)

    timer = Process.send_after(self(), :timeout, 90_000)

    {:noreply, %{state | taxis: taxis, timer: timer}}
  end

  def handle_info(:timeout, %{accepted_taxi: accepted} = state) when accepted != nil do
    {:noreply, state}
  end

  def handle_info(:timeout, %{request: request} = state) do
    %{"username" => customer} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
      %{msg: "No drivers available. Your booking has been cancelled.", status: "rejected"})
    {:noreply, state}
  end

  def handle_cast({:process_accept, _username}, %{accepted_taxi: accepted} = state) when accepted != nil do
    {:noreply, state}
  end

  def handle_cast({:process_accept, username}, %{taxis: taxis, request: request, timer: timer} = state) do
    if timer != nil, do: Process.cancel_timer(timer)

    accepted = Enum.find(taxis, fn t -> t.nickname == username end)

    taxis
    |> Enum.reject(fn t -> t.nickname == username end)
    |> Enum.each(fn t ->
      TaxiBeWeb.Endpoint.broadcast("driver:" <> t.nickname, "booking_cancelled", %{})
    end)

    eta_minutes = Enum.random(5..10)
    eta_seconds = eta_minutes * 60
    %{"username" => customer} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
      %{msg: "Driver #{username} accepted! Estimated arrival: #{eta_minutes} minutes.", status: "accepted"})

    {:noreply, %{state |
      accepted_taxi: accepted,
      timer: nil,
      eta_seconds: eta_seconds,
      accepted_at: System.monotonic_time(:second)
    }}
  end

  def handle_cast({:process_reject, _username}, %{accepted_taxi: accepted} = state) when accepted != nil do
    {:noreply, state}
  end

  def handle_cast({:process_reject, username}, %{taxis: taxis, request: request, rejected: rejected, timer: timer} = state) do
    new_rejected = MapSet.put(rejected, username)

    if MapSet.size(new_rejected) == length(taxis) do
      if timer != nil, do: Process.cancel_timer(timer)
      %{"username" => customer} = request
      TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
        %{msg: "No drivers available. Your booking has been cancelled.", status: "rejected"})
      {:noreply, %{state | rejected: new_rejected, timer: nil}}
    else
      {:noreply, %{state | rejected: new_rejected}}
    end
  end

  def handle_cast({:process_cancel, _username}, %{accepted_taxi: nil, taxis: taxis, timer: timer, request: request} = state) do
    if timer != nil, do: Process.cancel_timer(timer)
    Enum.each(taxis, fn taxi ->
      TaxiBeWeb.Endpoint.broadcast("driver:" <> taxi.nickname, "booking_cancelled", %{})
    end)
    %{"username" => customer} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
      %{msg: "Trip cancelled.", status: "cancelled"})
    {:noreply, %{state | timer: nil}}
  end

  def handle_cast({:process_cancel, _username}, %{accepted_taxi: accepted_taxi, accepted_at: accepted_at, eta_seconds: eta_seconds, request: request} = state) do
    elapsed = System.monotonic_time(:second) - accepted_at
    remaining = eta_seconds - elapsed
    %{"username" => customer} = request

    msg = if remaining <= 180 do
      "Trip cancelled. A $20 cancellation fee applies (taxi was #{max(remaining, 0)} seconds away)."
    else
      "Trip cancelled. No cancellation fee."
    end

    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
      %{msg: msg, status: "cancelled"})
    TaxiBeWeb.Endpoint.broadcast("driver:" <> accepted_taxi.nickname, "booking_cancelled", %{})
    {:noreply, state}
  end

  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "merry", latitude: 19.0092933, longitude: -98.2473716}
    ]
  end
end
