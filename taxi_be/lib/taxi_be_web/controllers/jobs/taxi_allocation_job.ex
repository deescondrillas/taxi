defmodule TaxiBeWeb.TaxiAllocationJob do
    use GenServer

    def start_link(request, name) do
        GenServer.start_link(__MODULE__, request, name: name)
    end

    def init(request) do
        Process.send(self(), :step1, [:nosuspend])
        {:ok, %{request: request}}
    end

    def handle_info(:step1, %{request: request} = state) do
        Process.sleep(1000)

        task = Task.async(fn -> candidate_taxis() end)
        # Computation of fare
        IO.puts(message = "The ride will have a cost of #{Enum.random([70, 75, 80, 85, 90, 95])} pesos")
        TaxiBeWeb.Endpoint.broadcast("customer:luciano", "booking_request", %{msg: message})

        taxis = Task.await(task)

        {taxi, others, timer} = part2(state |> Map.put(:taxis, taxis |> Enum.shuffle))
        {:noreply, state |> Map.put(:contacted_taxi, taxi) |> Map.put(:others, others) |> Map.put(:timer, timer)}
    end

    def handle_info(:timeout, %{others: others, request: request} = state) do
      case others do
        [] ->
          %{"username" => customer} = request
          TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
            %{msg: "No drivers available. Your booking has been cancelled.", status: "rejected"})
          {:noreply, state}
        _ ->
          {taxi, remaining, timer} = part2(state |> Map.put(:taxis, others))
          {:noreply, state |> Map.put(:contacted_taxi, taxi) |> Map.put(:others, remaining) |> Map.put(:timer, timer)}
      end
    end

    def part2(state) do
      %{taxis: taxis, request: request} = state
      [taxi | others] = taxis
      # Forward request to taxi driver
      %{
        "pickup_address" => pickup_address,
        "dropoff_address" => dropoff_address,
        "booking_id" => booking_id
      } = request
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> taxi.nickname,
        "booking_request",
         %{
           msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
           bookingId: booking_id
          })
      timer = Process.send_after(self(), :timeout, 10000)
      {taxi, others, timer}
    end

    def handle_cast({:process_cancel, _username}, %{contacted_taxi: taxi, timer: timer} = state) do
        if timer != nil, do: Process.cancel_timer(timer)
        TaxiBeWeb.Endpoint.broadcast("driver:" <> taxi.nickname, "booking_cancelled", %{})
        {:noreply, state}
    end

    def handle_cast({:process_reject, _username}, %{others: others, request: request, timer: timer} = state) do
        if timer != nil, do: Process.cancel_timer(timer)
        case others do
          [] ->
            %{"username" => customer} = request
            TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request",
              %{msg: "No drivers available. Your booking has been cancelled.", status: "rejected"})
            {:noreply, state}
          _ ->
            {taxi, remaining, new_timer} = part2(state |> Map.put(:taxis, others))
            {:noreply, state |> Map.put(:contacted_taxi, taxi) |> Map.put(:others, remaining) |> Map.put(:timer, new_timer)}
        end
    end

    def handle_cast(request, state) do
        IO.inspect(request)
        IO.inspect(state)

        %{timer: timer} = state
        if timer != nil do
          Process.cancel_timer(timer)
        end

        time = [5, 6, 7, 8, 9, 10]
        Process.sleep(10)
        IO.puts(message = "The driver will be arriving in #{Enum.random(time)} minutes")
        TaxiBeWeb.Endpoint.broadcast("customer:luciano", "booking_request", %{msg: message, status: "accepted"})
        {:noreply, state}
    end

    def compute_ride_fare(request) do
        %{"pickup_address" => pickup_address, "dropoff_address" => dropoff_address} = request
        # coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
        # coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)
        # {distance, _duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, cord2)
        distance = 80 * 300
        {request, Float.ceil(distance/300)}
    end

    def notify_customer_ride_fare({request, fare}) do
        %{"username" => customer} = request
        TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Ride fare: #{fare}"})
    end

    def select_candidate_taxis(%{"pickup_address" => _pickup_address}) do
        [
            %{nickname: "angelopolis", latitude: 19.0319783, longitude: -98.2349368},
            %{nickname: "arcangeles", latitude: 19.0061167, longitude: -98.2697737},
            %{nickname: "destino", latitude: 19.0092933, longitude: -98.2473716}
        ]
    end

    def candidate_taxis() do
        [
            %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
            %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
            %{nickname: "merry", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
        ]
    end
end
