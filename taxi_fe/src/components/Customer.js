import React, {useEffect, useRef, useState} from 'react';
import Button from '@mui/material/Button'

import socket from '../services/taxi_socket';
import { TextField } from '@mui/material';

function Customer(props) {
  let [pickupAddress, setPickupAddress] = useState("Tecnologico de Monterrey, campus Puebla, Mexico");
  let [dropOffAddress, setDropOffAddress] = useState("Triangulo Las Animas, Puebla, Mexico");
  let [bookingId, setBookingId] = useState("");
  // var bookingId = "";
  let [msg, setMsg] = useState("");
  let [pendingRequest, setPendingRequest] = useState(false);
  const cancelledRef = useRef(false);

  useEffect(() => {
    let channel = socket.channel("customer:" + props.username, {token: "123"});
    channel.on("greetings", data => console.log(data));
    channel.on("booking_request", data => {
      console.log("Received", data);
      if (data.status === "cancelled") {
        cancelledRef.current = true;
        setMsg(data.msg);
        setPendingRequest(false);
      } else if (!cancelledRef.current) {
        setMsg(data.msg);
        if (data.status === "accepted" || data.status === "rejected") {
          setPendingRequest(false);
        }
      }
    });
    channel.join();
    return () => { channel.leave(); };
  }, [props.username]);

  let submit = () => {
    cancelledRef.current = false;
    setPendingRequest(true);
    fetch(`http://localhost:4000/api/bookings`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({pickup_address: pickupAddress, dropoff_address: dropOffAddress, username: props.username})
    }).then(resp => resp.json()).then(data => {
      setBookingId(data.booking_id);
      // setBookingId(data.bookingId);
      setMsg(data.msg);
    }).catch(() => setPendingRequest(false));
  };

  let cancel = () => {
    fetch(`http://localhost:4000/api/bookings/${bookingId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: "cancel", username: props.username })
    }).then(resp => resp.json()).then(data => console.log(data));
  };

  return (
    <div style={{textAlign: "center", borderStyle: "solid"}}>
      Customer: {props.username}
      <div>
          <TextField id="outlined-basic" label="Pickup address"
            fullWidth
            onChange={ev => setPickupAddress(ev.target.value)}
            value={pickupAddress}
            sx={{ my: "5px" }}
        />
          <TextField id="outlined-basic" label="Drop off address"
            fullWidth
            onChange={ev => setDropOffAddress(ev.target.value)}
            value={dropOffAddress}
            sx={{ my: "5px" }}
        />
        <Button onClick={submit} variant="outlined" color="primary" disabled={pendingRequest}>Submit</Button>
        <Button onClick={cancel} variant="contained" style={{margin: "10px"}}>Cancel</Button>
      </div>
      <div style={{backgroundColor: "lightcyan", height: "50px"}}>
        {msg}
      </div>
    </div>
  );
}

export default Customer;
