# TODO

## Roadmap

- [ ] General client reverse engineering
- [x] General server reverse engineering
- [x] Handshaking and offline login
- [ ] Accept all packets to keep a working stream
- [ ] Authentication code
- [ ] Make an internal server subset to handle client-side logic
- [ ] Render the world and its entities
- [ ] Menus

## Packets done

Inbounds: 30/57
Outbounds: 3/57
*Not all of the 57 packets are both inbounds and outbounds, this is just an indicator

## Soon

- [ ] NBT decoding and encoding library

## Subtasks

### NBT library

- [x] See what version was effective back then and study it a bit
- [x] Look at what decompiled code does
- [ ] Write encoder
- [ ] Write encoder tests
- [x] Write decoder
- [x] Write decoder tests
- [ ] Comptime defined decoder
- [ ] Inspect performance from the decoder