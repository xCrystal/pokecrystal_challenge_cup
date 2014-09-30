GenerateTeam:
	call ResetRNs

	ld hl, PartyMons
	ld bc, (PartyMon2 - PartyMon1) * 6
	ld a, 1
	call ByteFill
	
	ld hl, PartyMon1Item
	ld bc, PartyMon2 - PartyMon1
	ld e, 6
.clearNextItem	
	xor a
	ld [hl], a
	add hl, bc
	dec e
	jr nz, .clearNextItem
	
	ld hl, PartyMon1PokerusStatus
	ld bc, PartyMon2 - PartyMon1
	ld e, 6
.clearNextPokerus
	xor a
	ld [hl], a
	add hl, bc
	dec e
	jr nz, .clearNextPokerus	
	
	ld hl, PartyEnd
	ld [hl], $ff

; Species
	ld hl, PartyCount
	ld [hl], 6 ; six Pokémon
	call GenSpecies

; Moves	
	xor a ; start with Pokémon 0 of 0-5
.nextMon	
	push af
	ld hl, wBattle
	ld bc, wBattleEnd - wBattle
	xor a 
	call ByteFill ; fill area with $00 for later use
	pop af
	call GenMoves
	inc a
	cp 6
	jr nz, .nextMon
	
; Other
	call GenID
	call GenHappiness
	call GenEVsAndDVs
	call ResetExp

; Nicknames
	ld a, [PartySpecies]
	ld hl, PartyMonNicknames
	ld bc, PKMN_NAME_LENGTH
	call ResetNicknames
	ld a, [PartySpecies + 1]
	add hl, bc
	call ResetNicknames
	ld a, [PartySpecies + 2]
	add hl, bc
	call ResetNicknames 
	ld a, [PartySpecies + 3]
	add hl, bc
	call ResetNicknames
	ld a, [PartySpecies + 4]
	add hl, bc
	call ResetNicknames
	ld a, [PartySpecies + 5]
	add hl, bc
	call ResetNicknames	
	
	ret
	

ResetRNs: ; initialize the ten seeds to (pseudo) random numbers	
	ld c, 10
	ld hl, LinkBattleRNs
.nextRN
.notyet	
	ld a, [$cfff]
	inc a 
	ld [$cfff], a
	jr nz, .notyet
	call Random2
	ld a, [$cffe]
	inc a
	ld [$cffe], a
	cp 27 ; kinda random number here
	jr nz, .notyet
	xor a
	ld [$cffe], a
	
	ld a, [rDIV]
	ld b, a 
	ld a, [rTIMA] ; mix each seed up with the Timer Counter and the Divider Register
	add b
	ld [hli], a
	dec c
	jr nz, .nextRN
	ret
	
	
GenSpecies:
	ld de, PartySpecies
	ld hl, PartyMon1Species
	ld bc, PartyMon2 - PartyMon1
	jr .repeat 
	
.next
	inc de
	ld a, e
	cp $de ; did we reach seventh Pokémon?
	jr z, .done
	add hl, bc
	
.repeat:
	call Random2
	cp CELEBI + 1 
	jr nc, .repeat ; >= #252
	and a 
	jr z, .repeat ; = #000
	ld [hl], a 
	ld [de], a	
	jr nz, .next
	
.done	
	ret 
	
	
GenMoves:
	call IsSpecialCase ; certain Pokémon like Caterpie and Ditto learn no TMs and less than 4 moves
					   ; return carry if it's one of those Pokémon, and fill its moveset
	jp c, .doneSpecialCase				   
	push af ; save number of Pokémon
	ld hl, EvosAttacksPointers2
	ld de, PartySpecies
	add e ; which number of Pokémon are we dealing with (0-5)?
	ld e, a
	ld a, [de]
	dec a 
	ld b, 0
	ld c, a 
	add hl, bc 
	add hl, bc  
	ld a, [hli]
	ld h, [hl]
	ld l, a 

; hl now points to EvosAttacks of [PartySpeciesN]
.stillEvoData	
	ld a, [hl]
	inc hl
	and a 
	jr nz, .stillEvoData
	
; hl now points to start of move data	
	ld bc, wBattle ; save all the compatible moves in an array starting at wBattle
.copyLevelUpMove
	inc hl ; skip level byte
	ld a, [hl]
	ld [bc], a 
	inc bc 
	inc hl 
	ld a, [hl]
	and a ; more level-up moves?
	jr nz, .copyLevelUpMove
	push bc
	
.genEggMoves	
	ld hl, EggMovePointers2
	ld a, [de] ; ld a, [PartySpeciesN]
	dec a
	ld b, 0
	ld c, a 
	add hl, bc 
	add hl, bc
	ld a, [hli]
	ld h, [hl]
	ld l, a 
	
; hl now points to EggMoves of [PartySpeciesN]	
	pop bc
	push bc
.copyEggMove
	ld a, [hl]
	ld [bc], a 
	inc bc
	ld a, [hl]
	inc hl	
	cp $ff ; more egg moves?
	jr nz, .copyEggMove
	
; WIP
	ld a, [$cff8]
	and a
	jp z, .getMoves ; selected option was not to include TMs/HMs
	
	ld hl, BulbasaurBaseData2	
	ld a, [de] ; ld a, [PartySpeciesN]
	ld bc, IvysaurBaseData2 - BulbasaurBaseData2
	
.notThisMon	
	add hl, bc
	dec a
	jr nz, .notThisMon
	
	ld bc, 24 
	add hl, bc ; move to TMHM bit masks
	pop bc ; restore position in the move array (wBattle)
	ld a, [hl]
	ld d, 8 ; eight bits per byte
	ld e, 8 ; eight TMHM bytes
	jr .nextBit

.nextArray
	inc hl
	ld a, [hl]
	ld d, 8 ; initialize to first bit again

.nextBit	
	bit 0, a
	call z, copyTMHM ; was that bit set? if so, copy the move to the array
	srl a ; move to next TMHM (next bit)
	dec d
	jr nz, .nextBit
	dec e
	jr nz, .nextArray
	
; /WIP

.getMoves
	pop bc
	pop af ; restore number of Pokémon
	push af 
	ld bc, PartyMon1Moves
	and a
	jr z, .ok
	ld bc, PartyMon1Moves + PartyMon2 - PartyMon1 ; PartyMon2Moves
	dec a 
	jr z, .ok
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 2 
	dec a
	jr z, .ok
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 3  
	dec a
	jr z, .ok
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 4  
	dec a
	jr z, .ok	
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 5 ; PartyMon6Moves

; get 4 random moves and copy them in partyMonNMoves	
.ok	
.again1
	call Random2
	and $1f
	ld hl, wBattle
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hl] ; get a random move from the list
	and a 
	jr z, .again1 
	cp $ff
	jr z, .again1 
	ld [bc], a
	inc bc
	
.again2	
	call Random2
	and $1f
	ld hl, wBattle
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hl] ; get a random move from the list
	and a 
	jr z, .again2
	cp $ff
	jr z, .again2
	ld h, b
	ld l, c
	dec hl
	cp [hl] ; was this move already picked?
	jr z, .again2 
	ld [bc], a
	inc bc
	
.again3	
	call Random2
	and $1f
	ld hl, wBattle
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hl] ; get a random move from the list
	and a 
	jr z, .again3
	cp $ff
	jr z, .again3
	ld h, b
	ld l, c
	dec hl
	cp [hl] ; was this move picked first?
	jr z, .again3
	dec hl
	cp [hl] ; was this move picked second?
	jr z, .again3
	ld [bc], a
	inc bc

.again4	
	call Random2
	and $1f
	ld hl, wBattle
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hl] ; get a random move from the list
	and a 
	jr z, .again4
	cp $ff
	jr z, .again4
	ld h, b
	ld l, c
	dec hl
	cp [hl] ; was this move picked first?
	jr z, .again4
	dec hl
	cp [hl] ; was this move picked second?
	jr z, .again4	
	dec hl
	cp [hl] ; was this move picked third?
	jr z, .again4
	ld [bc], a
	
	pop af ; restore number of Pokémon
	
.doneSpecialCase	
	ret
	
IsSpecialCase:
	push af
	
	ld hl, PartySpecies
	ld b, 0
	ld c, a
	add hl, bc ; PartySpeciesN
	
	ld bc, PartyMon1Moves
	and a
	jr z, .ok2
	ld bc, PartyMon1Moves + PartyMon2 - PartyMon1 ; PartyMon2Moves
	dec a 
	jr z, .ok2
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 2 
	dec a
	jr z, .ok2
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 3  
	dec a
	jr z, .ok2
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 4  
	dec a
	jr z, .ok2	
	ld bc, PartyMon1Moves + (PartyMon2 - PartyMon1) * 5 ; PartyMon6Moves
	
.ok2	
	ld a, [hl]
	ld h, b
	ld l, c ; hl = PartyMonNMoves
	cp CATERPIE
	jr z, ._Caterpie
	cp METAPOD
	jr z, ._Metapod
	cp WEEDLE
	jr z, ._Weedle
	cp KAKUNA
	jr z, ._Kakuna
	cp MAGIKARP
	jr z, ._Magikarp
	cp UNOWN
	jr z, ._Unown
	cp WOBBUFFET
	jr z, ._Wobbuffet
	cp DITTO
	jr z, ._Ditto
	cp SMEARGLE
	jr z, ._Smeargle
	jr .none ; not a special Pokémon

._Caterpie
	ld a, TACKLE
	ld [hli], a
	ld a, STRING_SHOT
	ld [hli], a
	xor a
	ld [hli], a
	ld [hl], a
	jr .finished

._Metapod
	ld a, TACKLE
	ld [hli], a
	ld a, STRING_SHOT
	ld [hli], a
	ld a, HARDEN
	ld [hli], a
	xor a
	ld [hl], a
	jr .finished
	
._Weedle
	ld a, POISON_STING
	ld [hli], a
	ld a, STRING_SHOT
	ld [hli], a
	xor a
	ld [hli], a
	ld [hl], a
	jr .finished

._Kakuna
	ld a, POISON_STING
	ld [hli], a
	ld a, STRING_SHOT
	ld [hli], a
	ld a, HARDEN
	ld [hli], a
	xor a
	ld [hl], a	
	jr .finished
	
._Magikarp
	ld a, SPLASH
	ld [hli], a
	ld a, TACKLE
	ld [hli], a
	ld a, FLAIL
	ld [hli], a
	xor a
	ld [hl], a
	jr .finished

._Unown
	ld a, HIDDEN_POWER
	ld [hli], a
	xor a 
	ld [hli], a
	ld [hli], a
	ld [hl], a
	jr .finished

._Wobbuffet
	ld a, COUNTER
	ld [hli], a
	ld a, MIRROR_COAT
	ld [hli], a
	ld a, SAFEGUARD
	ld [hli], a
	ld a, DESTINY_BOND
	ld [hl], a	
	jr .finished

._Ditto
	ld a, TRANSFORM
	ld [hli], a
	xor a 
	ld [hli], a
	ld [hli], a
	ld [hl], a
	jr .finished

._Smeargle
	ld a, SKETCH
	ld [hli], a
	xor a 
	ld [hli], a
	ld [hli], a
	ld [hl], a
	jr .finished		
	
.finished	
	pop af
	scf
	ret
	
.none
	pop af	
	scf
	ccf
	ret	


GenID:
	ld hl, PartyMon1ID
	ld de, PartyMon2 - PartyMon1	
	ld b, 6
.nextID	
	call Random2
	ld [hli], a
	call Random2
	ld [hld], a
	ld de, PartyMon2 - PartyMon1
	add hl, de
	dec b
	jr nz, .nextID
	ret
	
	
GenHappiness:
	ld hl, PartyMon1Happiness
	ld de, PartyMon2 - PartyMon1	
	ld b, 6
.nextHappiness
	call Random2
	ld [hl], a
	add hl, de
	dec b
	jr nz, .nextHappiness
	ret	
	
	
GenEVsAndDVs:
	ld hl, PartyMon1StatExp
	ld de, PartyMon2 - PartyMon1	
	ld b, 6
.nextEVsAndDVs	
	push hl
	call Random2
	ld [hli], a ; HP
	call Random2
	ld [hli], a ; HP	
	call Random2
	ld [hli], a ; Atk
	call Random2
	ld [hli], a ; Atk	
	call Random2
	ld [hli], a ; Def
	call Random2
	ld [hli], a ; Def	
	call Random2
	ld [hli], a ; Spd
	call Random2
	ld [hli], a ; Spd	
	call Random2
	ld [hli], a ; Spc
	call Random2
	ld [hli], a ; Spc	
	call Random2
	ld [hli], a ; AtkDefDV
	call Random2
	ld [hl], a ; SpdSpcDV
	pop hl
	add hl, de
	dec b
	jr nz, .nextEVsAndDVs
	ret
	
	
ResetExp:
	ld hl, PartyMon1Exp
	ld de, PartyMon2 - PartyMon1
	ld b, 6
.nextExp	
	ld [hl], $0f
	inc hl
	ld [hl], $42
	inc hl
	ld [hl], $40 ; 1000000
	dec hl
	dec hl
	add hl, de
	dec b
	jr nz, .nextExp
	ret
	
	
ResetNicknames:
	push hl
	ld d, h
	ld e, l ; ld de, PartyMonNNickname
	ld [$d265], a
	push de
	call GetPokemonName
	pop de
	ld hl, StringBuffer1
	ld bc, PKMN_NAME_LENGTH
	push bc
	call CopyBytes ; copy name to PartyMonNNickname (de)
	pop bc
	pop hl
	ret
	
	
Random2:
; Hijacked the RNG function used for link battles
; Using the normal RNG function would lead to obvious patterns
; This way we at least hide them	

; The PRNG operates in streams of 10 values.

; Which value are we trying to pull?
	push hl
	push bc
	ld a, [LinkBattleRNCount]
	ld c, a
	ld b, 0
	ld hl, LinkBattleRNs
	add hl, bc
	inc a
	ld [LinkBattleRNCount], a

; If we haven't hit the end yet, we're good
	cp 10 - 1 ; Exclude last value. See the closing comment
	ld a, [hl]
	pop bc
	pop hl
	ret c

; If we have, we have to generate new pseudorandom data
; Instead of having multiple PRNGs, ten seeds are used
	push hl
	push bc
	push af

; Reset count to 0
	xor a
	ld [LinkBattleRNCount], a
	ld hl, LinkBattleRNs
	ld b, 10 ; number of seeds

; Generate next number in the sequence for each seed
; The algorithm takes the form *5 + 1 % 256
.loop
	; get last #
	ld a, [hl]

	; a * 5 + 1
	ld c, a
	add a
	add a
	add c
	inc a

	; update #
	ld [hli], a
	dec b
	jr nz, .loop

; This has the side effect of pulling the last value first,
; then wrapping around. As a result, when we check to see if
; we've reached the end, we check the one before it.

	pop af
	pop bc
	pop hl
	ret
; 3ee0f	
	
	
INCLUDE "generate_team_data.asm"
	
