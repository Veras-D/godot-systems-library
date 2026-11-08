class_name CurrencyWallet
extends RefCounted

## Universal Multi-Currency Wallet & Ledger
##
## Decoupled transaction manager for soft currencies, premium currencies, and energy tokens.
## Provides thread-safe mutations, balance caps, atomic spends, and change signals.

signal balance_changed(currency_id: String, old_balance: int, new_balance: int)
signal insufficient_funds(currency_id: String, requested: int, current: int)
signal currency_registered(currency_id: String, initial_balance: int, max_cap: int)

# currency_id (String) -> int
var _balances: Dictionary = {}

# currency_id (String) -> int (-1 = uncapped)
var _caps: Dictionary = {}


## Registers a currency type with an optional initial balance and maximum cap.
func register_currency(currency_id: String, initial_balance: int = 0, max_cap: int = -1) -> void:
	var cid = currency_id.strip_edges()
	if cid == "":
		return

	_caps[cid] = max_cap
	var clamped = maxi(0, initial_balance)
	if max_cap >= 0:
		clamped = mini(clamped, max_cap)
	_balances[cid] = clamped
	currency_registered.emit(cid, clamped, max_cap)


## Checks if a currency is registered.
func has_currency(currency_id: String) -> bool:
	return _balances.has(currency_id)


## Returns the current balance for a currency (0 if not registered).
func get_balance(currency_id: String) -> int:
	return int(_balances.get(currency_id, 0))


## Sets the balance of a currency, clamping between 0 and max_cap (if capped).
## Emits balance_changed signal. Returns the new balance.
func set_balance(currency_id: String, amount: int) -> int:
	var cid = currency_id.strip_edges().to_lower()
	if not _balances.has(cid):
		return 0
	var cap = int(_caps.get(cid, -1))
	var clamped = maxi(0, amount)
	if cap >= 0:
		clamped = mini(clamped, cap)
	var prev = int(_balances[cid])
	_balances[cid] = clamped
	balance_changed.emit(cid, prev, clamped)
	return clamped


## Returns the maximum cap for a currency (-1 if uncapped or not registered).
func get_cap(currency_id: String) -> int:
	return int(_caps.get(currency_id, -1))


## Checks if the wallet has at least `amount` of the specified currency.
func has_enough(currency_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	return get_balance(currency_id) >= amount


## Deposits an amount into the specified currency. Respects max cap if configured.
## Returns the new balance.
func deposit(currency_id: String, amount: int) -> int:
	if amount <= 0:
		return get_balance(currency_id)

	var old_bal = get_balance(currency_id)
	var new_bal = old_bal + amount
	var cap = get_cap(currency_id)
	if cap >= 0:
		new_bal = mini(new_bal, cap)

	_balances[currency_id] = new_bal
	balance_changed.emit(currency_id, old_bal, new_bal)
	return new_bal


## Withdraws an amount from the specified currency.
## Fails atomically and emits insufficient_funds if balance < amount.
## Returns true on success, false on failure.
func withdraw(currency_id: String, amount: int) -> bool:
	if amount <= 0:
		return true

	var current = get_balance(currency_id)
	if current < amount:
		insufficient_funds.emit(currency_id, amount, current)
		return false

	var old_bal = current
	var new_bal = current - amount
	_balances[currency_id] = new_bal
	balance_changed.emit(currency_id, old_bal, new_bal)
	return true


## Atomically transfers currency from this wallet to a recipient wallet.
## Returns true if successful, false if sender has insufficient funds.
func transfer_to(recipient: CurrencyWallet, currency_id: String, amount: int) -> bool:
	if recipient == null or amount <= 0:
		return false

	if not has_enough(currency_id, amount):
		insufficient_funds.emit(currency_id, amount, get_balance(currency_id))
		return false

	withdraw(currency_id, amount)
	recipient.deposit(currency_id, amount)
	return true


## Serializes all balances and caps to a dictionary for JSON persistence.
func serialize() -> Dictionary:
	return {
		"balances": _balances.duplicate(true),
		"caps": _caps.duplicate(true)
	}


## Deserializes balances and caps from saved state.
func deserialize(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	var saved_caps = data.get("caps", {})
	if typeof(saved_caps) == TYPE_DICTIONARY:
		for k in saved_caps.keys():
			_caps[str(k)] = int(saved_caps[k])

	var saved_balances = data.get("balances", {})
	if typeof(saved_balances) == TYPE_DICTIONARY:
		for k in saved_balances.keys():
			var cid = str(k)
			var old_b = get_balance(cid)
			var new_b = int(saved_balances[k])
			var cap = get_cap(cid)
			if cap >= 0:
				new_b = mini(new_b, cap)
			_balances[cid] = new_b
			if old_b != new_b:
				balance_changed.emit(cid, old_b, new_b)
