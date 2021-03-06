GenerateTeam:
	push af
	push bc
	push de
	push hl

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
	
	ld hl, PartyMon1Status
	ld bc, PartyMon2 - PartyMon1
	ld e, 6
.clearNextStatus
	xor a
	ld [hl], a
	add hl, bc
	dec e
	jr nz, .clearNextStatus

	ld hl, PartyMon1Level
	ld bc, PartyMon2 - PartyMon1
	ld e, 6
.setNextLevel
	ld a, 100
	ld [hl], a
	add hl, bc
	dec e
	jr nz, .setNextLevel
	
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
	call CalcPP
	
; Other
	call GenID
	call GenHappiness
	call GenEVsAndDVs
	ld a, 100
	ld [CurPartyLevel], a
	call CalcStats
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
	
	pop hl
	pop de
	pop bc
	pop af
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
	jr .repeat 
	
.next
	inc de
	ld a, e
	cp $de ; did we reach seventh Pokémon?
	jr z, .done
	ld bc, PartyMon2 - PartyMon1
	add hl, bc
	
.repeat:
	call Random2
	cp CELEBI + 1 
	jr nc, .repeat ; >= #252
	and a 
	jr z, .repeat ; = #000
	 
	ld b, a
	ld a, [$cff7] ; check whether NFE-less option was selected
	and a 
	scf ; if it wasn't, set carry regardless of NFE or not
	call nz, IsNFE ; return non carry if mon is NFE, carry otherwise
	jr nc, .repeat 
	ld a, b
	
	ld [hl], a 
	ld [de], a	
	jr .next
	
.done	
	ret 
	
	
IsNFE:
	push hl
	push de
	push bc
	ld a, b
	ld hl, EvosAttacksPointers2
	dec a
	ld d, 0
	ld e, a
	add hl, de
	add hl, de ; move to pointer
	ld a, [hli]
	ld h, [hl]
	ld l, a ; load pointed address into hl
	ld a, [hl] 
	and a ; if the first byte is 00, the Pokemon does not evolve
	scf
	jr z, .NotNFE
	ccf
.NotNFE	
	pop bc
	pop de
	pop hl
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
	ld [bc], a 
	inc bc ; Level up moves as well as egg moves get copied twice
		   ; so that they appear more commonly than TM/HM moves
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
.copyEggMove
	ld a, [hl]
	ld [bc], a 
	inc bc
	ld [bc], a 
	inc bc	
	ld a, [hl]
	inc hl	
	cp $ff ; more egg moves?
	jr nz, .copyEggMove
	
	ld a, [$cff8]
	and a
	jp z, .getMoves ; selected option was not to include TMs/HMs
	
	ld hl, BulbasaurBaseData2	
	ld a, [de] ; ld a, [PartySpeciesN]
	dec a
	push bc
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
	call nz, CopyTMHM ; was that bit set? if so, copy the move to the array
	srl a ; move to next TMHM (next bit)
	dec d
	jr nz, .nextBit
	dec e
	jr nz, .nextArray
	

.getMoves
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
	and $7f ; stupid Mew learning over 63 moves...
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
	and $7f
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
	and $7f
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
	and $7f
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
	
	
CopyTMHM:

	push af
	push de
	push hl
	
	; current move is at TMHMList + 72 - (e * 8 + d)	
	; copy it to bc and inc bc
	ld hl, TMHMList
	sla e 
	sla e
	sla e ; e * 8
	ld a, 72
	sub e
	sub d
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hl]
	ld [bc], a
	inc bc
	
	pop hl
	pop de
	pop af
	ret	
	
TMHMList:
	db DYNAMICPUNCH
	db HEADBUTT
	db CURSE
	db ROLLOUT
	db ROAR
	db TOXIC
	db ZAP_CANNON
	db ROCK_SMASH
	db PSYCH_UP
	db HIDDEN_POWER
	db SUNNY_DAY
	db SWEET_SCENT
	db SNORE
	db BLIZZARD
	db HYPER_BEAM
	db ICY_WIND
	db PROTECT
	db RAIN_DANCE
	db GIGA_DRAIN
	db ENDURE
	db FRUSTRATION
	db SOLARBEAM
	db IRON_TAIL
	db DRAGONBREATH
	db THUNDER
	db EARTHQUAKE
	db RETURN
	db DIG
	db PSYCHIC_M
	db SHADOW_BALL
	db MUD_SLAP
	db DOUBLE_TEAM
	db ICE_PUNCH
	db SWAGGER
	db SLEEP_TALK
	db SLUDGE_BOMB
	db SANDSTORM
	db FIRE_BLAST
	db SWIFT
	db DEFENSE_CURL
	db THUNDERPUNCH
	db DREAM_EATER
	db DETECT
	db REST
	db ATTRACT
	db THIEF
	db STEEL_WING
	db FIRE_PUNCH
	db FURY_CUTTER
	db NIGHTMARE
	db CUT
	db FLY
	db SURF
	db STRENGTH
	db FLASH
	db WHIRLPOOL
	db WATERFALL
	db FLAMETHROWER
	db THUNDERBOLT
	db ICE_BEAM
	db 0, 0, 0, 0


CalcPP:
	ld a, 6
	ld [$dfff], a 
	ld hl, PartyMon1Moves - (PartyMon2 - PartyMon1)
	ld de, PartyMon1PP - (PartyMon2 - PartyMon1)
	ld bc, PartyMon2 - PartyMon1
.loop
	push hl
	ld h, d
	ld l, e
	add hl, bc
	ld d, h
	ld e, l
	pop hl
	add hl, bc
	push hl
	push de
	push bc
	predef FillPP
	pop bc
	pop de
	pop hl
	ld a, [$dfff]
	dec a
	ld [$dfff], a
	jr nz, .loop
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
	

CalcStats:
	ld a, [PartyMon1Species]
	ld hl, CurSpecies
	ld [hl], a
	call GetBaseData
	ld de, PartyMon1MaxHP
	ld hl, PartyMon1Exp + 2
	ld b, 1
	predef Functione167	
	ld a, [PartyMon1MaxHP]
	ld hl, PartyMon1HP
	ld [hli], a
	ld a, [PartyMon1MaxHP + 1]
	ld [hl], a	
	
	ld a, [PartyMon2Species]
	ld hl, CurSpecies
	ld [hl], a
	call GetBaseData	
	ld de, PartyMon2MaxHP
	ld hl, PartyMon2Exp + 2
	ld b, 1
	predef Functione167
	ld a, [PartyMon2MaxHP]
	ld hl, PartyMon2HP
	ld [hli], a
	ld a, [PartyMon2MaxHP + 1]
	ld [hl], a		
	
	ld a, [PartyMon3Species]
	ld hl, CurSpecies
	ld [hl], a
	call GetBaseData	
	ld de, PartyMon3MaxHP
	ld hl, PartyMon3Exp + 2
	ld b, 1
	predef Functione167
	ld a, [PartyMon3MaxHP]
	ld hl, PartyMon3HP
	ld [hli], a
	ld a, [PartyMon3MaxHP + 1]
	ld [hl], a		
	
	ld a, [PartyMon4Species]
	ld hl, CurSpecies
	ld [hl], a
	call GetBaseData	
	ld de, PartyMon4MaxHP
	ld hl, PartyMon4Exp + 2
	ld b, 1
	predef Functione167	
	ld a, [PartyMon4MaxHP]
	ld hl, PartyMon4HP
	ld [hli], a
	ld a, [PartyMon4MaxHP + 1]
	ld [hl], a	
	
	ld a, [PartyMon5Species]
	ld hl, CurSpecies
	ld [hl], a	
	call GetBaseData	
	ld de, PartyMon5MaxHP
	ld hl, PartyMon5Exp + 2
	ld b, 1
	predef Functione167
	ld a, [PartyMon5MaxHP]
	ld hl, PartyMon5HP
	ld [hli], a
	ld a, [PartyMon5MaxHP + 1]
	ld [hl], a		
	
	ld a, [PartyMon6Species]
	ld hl, CurSpecies
	ld [hl], a
	call GetBaseData	
	ld de, PartyMon6MaxHP
	ld hl, PartyMon6Exp + 2
	ld b, 1
	predef Functione167
	ld a, [PartyMon6MaxHP]
	ld hl, PartyMon6HP
	ld [hli], a
	ld a, [PartyMon6MaxHP + 1]
	ld [hl], a		
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