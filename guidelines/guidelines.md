# Uber-be-like system
## 1. Completing the application
- A user is able to submit a request
- A taxi driver is contacted one at a time
- If the taxi rejects, or 90 seconds pass, the following one is contacted
- If taxi accepts, the customer receives estimated time and fee

## 2. Creating a parallel version
- The three drivers are contacted simultaneously
- If no driver answers after 90 seconds, the ride is cancelled (notifies customer)
- When a driver answers, the other three stop seeing the 'accept' message
- The customer is notified with estimated time and fee
- The customer may cancel the trip (before the taxi arrives)
  - If it's done <= 180 seconds before the taxi arrives, there is a compensation fee of $20
  - Else, cancellation is free
