import urllib.request
import json
import time

BASE_URL = "http://localhost:3001/api/v1"


def req(method, endpoint, data=None, token=None):
    url = f"{BASE_URL}{endpoint}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    encoded_data = json.dumps(data).encode("utf-8") if data else None

    request = urllib.request.Request(
        url, data=encoded_data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode())
    except urllib.request.HTTPError as e:
        print(f"Error {endpoint}: {e.code} {e.read().decode()}")
        return None


def main():
    print("Starting Verification (Refactor)...")

    # 1. Register User A
    ts = int(time.time())
    user_a = f"user_x_{ts}"
    pass_a = "password"
    resp_a = req("POST", "/auth/register", {"username": user_a, "password": pass_a})
    if not resp_a:
        resp_a = req("POST", "/auth/login", {"username": user_a, "password": pass_a})
    token_a = resp_a["token"]

    # 2. Simulate Market Data/Account Creation
    # Note: Account is now created implicitly or explicitly via Bind or Status
    mt4_acc = 999000 + (ts % 1000)
    broker = "RefactorBroker"

    # Send account status (Directly inserts to account_status table)
    print("Sending Account Status...")
    req(
        "POST",
        "/account",
        {
            "balance": 50000.0,
            "equity": 50000.0,
            "margin": 0.0,
            "free_margin": 50000.0,
            "floating_profit": 0.0,
            "timestamp": ts,
            "mt4_account": mt4_acc,
            "broker": broker,
            "positions": [],
        },
    )

    # 3. Bind User A
    print("Binding User A...")
    bind_res = req(
        "POST",
        "/accounts/bind",
        {
            "mt4_account": mt4_acc,
            "broker": broker,
            "account_name": "My Refactored Account",
        },
        token=token_a,
    )
    print("Bind Result:", bind_res)

    # 4. Verify List Accounts
    print("Listing Accounts...")
    list_res = req("GET", "/accounts", token=token_a)
    print("List Result:", list_res)

    found = any(a["mt4_account"] == mt4_acc and a["broker"] == broker for a in list_res)
    if found:
        print("SUCCESS: Account listed correctly.")
    else:
        print("FAILURE: Account not found in list.")
        return

    # 5. Check Data Access (Get State)
    # Using mt4_account and broker query params
    print("Checking Get State...")
    state_res = req(
        "GET", f"/state?mt4_account={mt4_acc}&broker={broker}", token=token_a
    )
    if state_res and state_res["account_status"]["equity"] == 50000.0:
        print("SUCCESS: State data retrieved correctly.")
    else:
        print("FAILURE: State data mismatch or verify failed.", state_res)

    # 6. Check History
    print("Checking History...")
    hist_res = req(
        "GET", f"/account/history?mt4_account={mt4_acc}&broker={broker}", token=token_a
    )
    if hist_res and len(hist_res) > 0:
        print("SUCCESS: History retrieved.")
    else:
        print("FAILURE: History empty or failed.", hist_res)


if __name__ == "__main__":
    main()
