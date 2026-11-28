# Per-app proxy: send one program through the proxy

[中文](per-app-proxy.md) · [README](../README.en.md) · [Leak protection](leak-protection.en.md)

> In short: **the router cannot tell which program on a computer is sending traffic**, so per-app routing is set up on the computer or phone. LaneKeep's dedicated entries let the program you choose use the proxy on its own while other programs are unaffected.

## Why the router cannot do it

A router is like a building's front desk: it sees that a parcel came from flat 201 (the device's IP address), not which person in the flat sent it (which program).

So LaneKeep routes per device: once a device is in a mode, every program on it follows that mode's rules.

To have only one program on a computer use the proxy, you tell that program on the computer: "use the router's dedicated entry".

## First, open a dedicated entry in LaneKeep

1. Make sure the computer is in **Global, Enhanced or On-demand** mode (on the Devices page). Standard and Direct modes cannot use dedicated entries.
2. Open the Rules page, switch to the computer's mode, find the dedicated entry card and click **Add port**.
3. Choose the exit: proxy (default node), a specific node, or direct.
4. Click **Review changes** at the bottom and confirm.
5. Note two values for later:
   - **Address**: the router's LAN address, for example `10.0.0.1` (use your router's)
   - **Port**: the port you were given, between `10811` and `10860`

## Method 1: only Chrome or Edge (easiest)

LaneKeep has this built in; nothing else to install.

1. After applying, reload the Rules page and click **Enable** after Chrome or Edge on the port's row to download a `.reg` file.
2. Double-click the file on the Windows computer and choose "Yes" when asked (administrator rights needed).
3. **Quit the browser completely** (including its tray icon) and open it again.
4. "Managed by your organization" in the browser settings is expected.

To turn it off: click **Disable** on the same row, run the downloaded file, then quit and reopen the browser.

## Method 2: the program has its own proxy settings

Many programs have a "Proxy" or "Connection type" setting. Fill it in like this:

| Field | Value |
|---|---|
| Proxy type | **SOCKS5** (not HTTP) |
| Address / host | The router's LAN address, for example `10.0.0.1` |
| Port | The dedicated entry port, for example `10820` |
| Username / password | Leave empty |
| "Resolve hostnames through the proxy" / "Remote DNS" | **Must be on** |

Firefox, for example (menu names may change between versions): Settings → General → Network Settings → Settings… → Manual proxy configuration; enter the address and port under **SOCKS Host**, choose **SOCKS v5**, and tick **Proxy DNS when using SOCKS v5**.

> **Why must "resolve hostnames through the proxy" be on?** In Global, Enhanced and On-demand modes the router hands devices fake IP addresses. If the program looks up the address itself and then connects to the dedicated entry, it brings a fake IP, which the entry rejects, so pages do not open. With the option on, the program passes the hostname to the entry and it works.

## Method 3: a client on the computer that routes by program name

If the program has no proxy setting, install a proxy client on the computer that supports rules by process or program name, and have it forward that program to the router's dedicated entry. The rules amount to:

```text
program is telegram.exe  →  forward to 10.0.0.1:10820 (SOCKS5, remote DNS)
every other program      →  connect directly (the router applies the device's mode)
```

Notes:

- Download such clients only from their official sources.
- If the client's "TUN", "virtual adapter" or "system proxy" mode is on, it takes over the whole computer and stacks on top of LaneKeep's device rules, which makes problems hard to trace. **Write rules only for the target program and leave everything else on "direct".**
- If the computer loses internet access, quit the client first, confirm the computer works again, then check the rules one by one.

## Phones

- **Android**: some proxy apps offer per-app proxying, where you pick just a few apps. Use the router address and dedicated entry port as the upstream, type SOCKS5, with remote DNS on.
- **iOS / iPadOS**: not really possible. The manual proxy in the system Wi-Fi settings is an HTTP proxy that applies to every app, and LaneKeep's dedicated entries are SOCKS5. Put the whole device in a suitable mode instead.

## Good to know

- **Only devices in the same mode can use the port.** A device moved out of the mode is refused. The port has no password.
- **SOCKS5 TCP only, no UDP.** Voice and video calls (UDP) and WebRTC in the program do not use the dedicated entry; they follow the device's mode.
- Dedicated entries have their own protection (private addresses, fake IPs, internal ports) and are not part of the custom rule order on the Rules page.
- **The kill switch still applies:** traffic is blocked when the default node is down; it does not switch to direct.
- **Before disabling or deleting a port, change the program's proxy setting back** (or run the browser's disable file), or the program loses internet access.

## FAQ

**Pages do not open after setting it up?** Check in this order:

1. Is the device in Global, Enhanced or On-demand mode?
2. Is the address the router's LAN address, and the port correct?
3. Is the type SOCKS5, with "resolve hostnames through the proxy / remote DNS" on?
4. Is the port enabled on the Rules page, and was the change applied?

**Can WeChat go direct while everything else uses the proxy?** Do it the other way round: put the computer in Global mode, add a dedicated entry whose exit is "direct", and use method 3 to forward WeChat to that port. Or add "direct" rules in Global mode for the domains WeChat uses. WeChat voice and video calls use UDP, skip the dedicated entry and follow Global mode's rules.

**Why not in Standard or Direct mode?** Those modes have no dedicated entries. Move the device to Global, Enhanced or On-demand mode first.
