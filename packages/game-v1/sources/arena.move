// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Arena module.
module prototype::arena {
    use sui::bcs;

    use pokemon::stats::{Self, Stats};
    use prototype::battle;

    public struct Arena has key {
        id: UID,
        seed: vector<u8>,
        round: u8,
        bot_stats: Stats,
        player_stats: Stats,
        is_over: bool
    }

    public struct ArenaCreated has copy, drop {
        arena: address,
        bot_stats: Stats,
        player_stats: Stats,
    }

    public struct ArenaHit has copy, drop {
        arena: address,
        bot_hp: u64,
        player_hp: u64,
    }

    #[allow(lint(share_owned))]
    /// Create and share a new arena.
    entry fun new(ctx: &mut TxContext) {
        transfer::share_object(new_(ctx));
    }

    entry fun attack(arena: &mut Arena, _move: u8, _ctx: &mut TxContext) {
        assert!(arena.is_over == false, 666);

        let player_rng = hit_rng(arena.seed, 3, arena.round);
        let bot_rng = hit_rng(arena.seed, 4, arena.round);
        let bot_move = hit_rng(arena.seed, 5, arena.round) % 3;

        battle::attack(
            &arena.player_stats,
            &mut arena.bot_stats,
            (_move as u64), player_rng, false
        );

        battle::attack(
            &arena.bot_stats,
            &mut arena.player_stats,
            (bot_move as u64), bot_rng, false
        );

        arena.round = arena.round + 1;

        let player_hp = arena.player_stats.hp();
        let bot_hp = arena.bot_stats.hp();

        if (player_hp == 0 || bot_hp == 0) {
            arena.is_over = true;
        };

        sui::event::emit(ArenaHit {
            arena: object::uid_to_address(&arena.id),
            player_hp,
            bot_hp,
        });
    }

    fun generate_stats(seed: vector<u8>): Stats {
        // let level = *vector::borrow(&seed, 8) % 10;
        // let level = if (level == 0) { 1 } else { level };
        let level = 10;
        stats::new(
            10 + smooth(seed[0]),
            smooth(seed[1]),
            smooth(seed[2]),
            smooth(seed[3]),
            smooth(seed[4]),
            smooth(seed[5]),
            level,
            vector[ seed[6] % 3 ]
        )
    }

    fun hit_rng(seed: vector<u8>, path: u8, round: u8): u8 {
        let value = derive(seed, path)[(round as u64)];
        ((value % (255 - 217)) + 217)
    }

    fun smooth(value: u8): u8 {
        let value = ((value % 60) + 60) / 2;
        if (value == 0) {
            10
        } else {
            value
        }
    }

    fun derive(mut seed: vector<u8>, path: u8): vector<u8> {
        seed.push_back(path);
        sui::hash::blake2b256(&seed)
    }

    fun new_(ctx: &mut TxContext): Arena {
        let addr = ctx.fresh_object_address();
        let seed = sui::hash::blake2b256(&bcs::to_bytes(&addr));
        let id = object::new(ctx);
        let arena = id.to_address();

        // Generate stats for player and bot.

        let player_stats = generate_stats(derive(seed, 0));
        let bot_stats = generate_stats(derive(seed, 1));

        // Emit events and share the Arena

        sui::event::emit(ArenaCreated {
            arena, player_stats, bot_stats
        });

        Arena {
            id, seed, bot_stats, player_stats, round: 0, is_over: false
        }
    }

    #[test] fun test_new_and_attack() {
        let ctx = &mut tx_context::dummy();

        // skip some IDs.
        ctx.fresh_object_address();
        ctx.fresh_object_address();

        let mut arena = new_(ctx);

        attack(&mut arena, 0, ctx);
        attack(&mut arena, 1, ctx);

        // std::debug::print(&arena.player_stats);
        // std::debug::print(&arena.bot_stats);

        transfer::share_object(arena);
    }
}
