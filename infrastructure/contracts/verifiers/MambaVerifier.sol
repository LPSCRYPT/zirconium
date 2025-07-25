// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MambaVerifier {
    uint256 internal constant    DELTA = 4131629893567559867359510883348571134090853742863529169391034518566172092834;
    uint256 internal constant        R = 21888242871839275222246405745257275088548364400416034343698204186575808495617; 

    uint256 internal constant FIRST_QUOTIENT_X_CPTR = 0x0f24;
    uint256 internal constant  LAST_QUOTIENT_X_CPTR = 0x10e4;

    uint256 internal constant                VK_MPTR = 0x05a0;
    uint256 internal constant         VK_DIGEST_MPTR = 0x05a0;
    uint256 internal constant     NUM_INSTANCES_MPTR = 0x05c0;
    uint256 internal constant                 K_MPTR = 0x05e0;
    uint256 internal constant             N_INV_MPTR = 0x0600;
    uint256 internal constant             OMEGA_MPTR = 0x0620;
    uint256 internal constant         OMEGA_INV_MPTR = 0x0640;
    uint256 internal constant    OMEGA_INV_TO_L_MPTR = 0x0660;
    uint256 internal constant   HAS_ACCUMULATOR_MPTR = 0x0680;
    uint256 internal constant        ACC_OFFSET_MPTR = 0x06a0;
    uint256 internal constant     NUM_ACC_LIMBS_MPTR = 0x06c0;
    uint256 internal constant NUM_ACC_LIMB_BITS_MPTR = 0x06e0;
    uint256 internal constant              G1_X_MPTR = 0x0700;
    uint256 internal constant              G1_Y_MPTR = 0x0720;
    uint256 internal constant            G2_X_1_MPTR = 0x0740;
    uint256 internal constant            G2_X_2_MPTR = 0x0760;
    uint256 internal constant            G2_Y_1_MPTR = 0x0780;
    uint256 internal constant            G2_Y_2_MPTR = 0x07a0;
    uint256 internal constant      NEG_S_G2_X_1_MPTR = 0x07c0;
    uint256 internal constant      NEG_S_G2_X_2_MPTR = 0x07e0;
    uint256 internal constant      NEG_S_G2_Y_1_MPTR = 0x0800;
    uint256 internal constant      NEG_S_G2_Y_2_MPTR = 0x0820;

    uint256 internal constant CHALLENGE_MPTR = 0x10c0;

    uint256 internal constant THETA_MPTR = 0x10c0;
    uint256 internal constant  BETA_MPTR = 0x10e0;
    uint256 internal constant GAMMA_MPTR = 0x1100;
    uint256 internal constant     Y_MPTR = 0x1120;
    uint256 internal constant     X_MPTR = 0x1140;
    uint256 internal constant  ZETA_MPTR = 0x1160;
    uint256 internal constant    NU_MPTR = 0x1180;
    uint256 internal constant    MU_MPTR = 0x11a0;

    uint256 internal constant       ACC_LHS_X_MPTR = 0x11c0;
    uint256 internal constant       ACC_LHS_Y_MPTR = 0x11e0;
    uint256 internal constant       ACC_RHS_X_MPTR = 0x1200;
    uint256 internal constant       ACC_RHS_Y_MPTR = 0x1220;
    uint256 internal constant             X_N_MPTR = 0x1240;
    uint256 internal constant X_N_MINUS_1_INV_MPTR = 0x1260;
    uint256 internal constant          L_LAST_MPTR = 0x1280;
    uint256 internal constant         L_BLIND_MPTR = 0x12a0;
    uint256 internal constant             L_0_MPTR = 0x12c0;
    uint256 internal constant   INSTANCE_EVAL_MPTR = 0x12e0;
    uint256 internal constant   QUOTIENT_EVAL_MPTR = 0x1300;
    uint256 internal constant      QUOTIENT_X_MPTR = 0x1320;
    uint256 internal constant      QUOTIENT_Y_MPTR = 0x1340;
    uint256 internal constant          R_EVAL_MPTR = 0x1360;
    uint256 internal constant   PAIRING_LHS_X_MPTR = 0x1380;
    uint256 internal constant   PAIRING_LHS_Y_MPTR = 0x13a0;
    uint256 internal constant   PAIRING_RHS_X_MPTR = 0x13c0;
    uint256 internal constant   PAIRING_RHS_Y_MPTR = 0x13e0;

    function verifyProof(
        bytes calldata proof,
        uint256[] calldata instances
    ) public returns (bool) {
        assembly {
            // Read EC point (x, y) at (proof_cptr, proof_cptr + 0x20),
            // and check if the point is on affine plane,
            // and store them in (hash_mptr, hash_mptr + 0x20).
            // Return updated (success, proof_cptr, hash_mptr).
            function read_ec_point(success, proof_cptr, hash_mptr, q) -> ret0, ret1, ret2 {
                let x := calldataload(proof_cptr)
                let y := calldataload(add(proof_cptr, 0x20))
                ret0 := and(success, lt(x, q))
                ret0 := and(ret0, lt(y, q))
                ret0 := and(ret0, eq(mulmod(y, y, q), addmod(mulmod(x, mulmod(x, x, q), q), 3, q)))
                mstore(hash_mptr, x)
                mstore(add(hash_mptr, 0x20), y)
                ret1 := add(proof_cptr, 0x40)
                ret2 := add(hash_mptr, 0x40)
            }

            // Squeeze challenge by keccak256(memory[0..hash_mptr]),
            // and store hash mod r as challenge in challenge_mptr,
            // and push back hash in 0x00 as the first input for next squeeze.
            // Return updated (challenge_mptr, hash_mptr).
            function squeeze_challenge(challenge_mptr, hash_mptr, r) -> ret0, ret1 {
                let hash := keccak256(0x00, hash_mptr)
                mstore(challenge_mptr, mod(hash, r))
                mstore(0x00, hash)
                ret0 := add(challenge_mptr, 0x20)
                ret1 := 0x20
            }

            // Squeeze challenge without absorbing new input from calldata,
            // by putting an extra 0x01 in memory[0x20] and squeeze by keccak256(memory[0..21]),
            // and store hash mod r as challenge in challenge_mptr,
            // and push back hash in 0x00 as the first input for next squeeze.
            // Return updated (challenge_mptr).
            function squeeze_challenge_cont(challenge_mptr, r) -> ret {
                mstore8(0x20, 0x01)
                let hash := keccak256(0x00, 0x21)
                mstore(challenge_mptr, mod(hash, r))
                mstore(0x00, hash)
                ret := add(challenge_mptr, 0x20)
            }

            // Batch invert values in memory[mptr_start..mptr_end] in place.
            // Return updated (success).
            function batch_invert(success, mptr_start, mptr_end) -> ret {
                let gp_mptr := mptr_end
                let gp := mload(mptr_start)
                let mptr := add(mptr_start, 0x20)
                for
                    {}
                    lt(mptr, sub(mptr_end, 0x20))
                    {}
                {
                    gp := mulmod(gp, mload(mptr), R)
                    mstore(gp_mptr, gp)
                    mptr := add(mptr, 0x20)
                    gp_mptr := add(gp_mptr, 0x20)
                }
                gp := mulmod(gp, mload(mptr), R)

                mstore(gp_mptr, 0x20)
                mstore(add(gp_mptr, 0x20), 0x20)
                mstore(add(gp_mptr, 0x40), 0x20)
                mstore(add(gp_mptr, 0x60), gp)
                mstore(add(gp_mptr, 0x80), sub(R, 2))
                mstore(add(gp_mptr, 0xa0), R)
                ret := and(success, staticcall(gas(), 0x05, gp_mptr, 0xc0, gp_mptr, 0x20))
                let all_inv := mload(gp_mptr)

                let first_mptr := mptr_start
                let second_mptr := add(first_mptr, 0x20)
                gp_mptr := sub(gp_mptr, 0x20)
                for
                    {}
                    lt(second_mptr, mptr)
                    {}
                {
                    let inv := mulmod(all_inv, mload(gp_mptr), R)
                    all_inv := mulmod(all_inv, mload(mptr), R)
                    mstore(mptr, inv)
                    mptr := sub(mptr, 0x20)
                    gp_mptr := sub(gp_mptr, 0x20)
                }
                let inv_first := mulmod(all_inv, mload(second_mptr), R)
                let inv_second := mulmod(all_inv, mload(first_mptr), R)
                mstore(first_mptr, inv_first)
                mstore(second_mptr, inv_second)
            }

            // Add (x, y) into point at (0x00, 0x20).
            // Return updated (success).
            function ec_add_acc(success, x, y) -> ret {
                mstore(0x40, x)
                mstore(0x60, y)
                ret := and(success, staticcall(gas(), 0x06, 0x00, 0x80, 0x00, 0x40))
            }

            // Scale point at (0x00, 0x20) by scalar.
            function ec_mul_acc(success, scalar) -> ret {
                mstore(0x40, scalar)
                ret := and(success, staticcall(gas(), 0x07, 0x00, 0x60, 0x00, 0x40))
            }

            // Add (x, y) into point at (0x80, 0xa0).
            // Return updated (success).
            function ec_add_tmp(success, x, y) -> ret {
                mstore(0xc0, x)
                mstore(0xe0, y)
                ret := and(success, staticcall(gas(), 0x06, 0x80, 0x80, 0x80, 0x40))
            }

            // Scale point at (0x80, 0xa0) by scalar.
            // Return updated (success).
            function ec_mul_tmp(success, scalar) -> ret {
                mstore(0xc0, scalar)
                ret := and(success, staticcall(gas(), 0x07, 0x80, 0x60, 0x80, 0x40))
            }

            // Perform pairing check.
            // Return updated (success).
            function ec_pairing(success, lhs_x, lhs_y, rhs_x, rhs_y) -> ret {
                mstore(0x00, lhs_x)
                mstore(0x20, lhs_y)
                mstore(0x40, mload(G2_X_1_MPTR))
                mstore(0x60, mload(G2_X_2_MPTR))
                mstore(0x80, mload(G2_Y_1_MPTR))
                mstore(0xa0, mload(G2_Y_2_MPTR))
                mstore(0xc0, rhs_x)
                mstore(0xe0, rhs_y)
                mstore(0x100, mload(NEG_S_G2_X_1_MPTR))
                mstore(0x120, mload(NEG_S_G2_X_2_MPTR))
                mstore(0x140, mload(NEG_S_G2_Y_1_MPTR))
                mstore(0x160, mload(NEG_S_G2_Y_2_MPTR))
                ret := and(success, staticcall(gas(), 0x08, 0x00, 0x180, 0x00, 0x20))
                ret := and(ret, mload(0x00))
            }

            // Modulus
            let q := 21888242871839275222246405745257275088696311157297823662689037894645226208583 // BN254 base field
            let r := 21888242871839275222246405745257275088548364400416034343698204186575808495617 // BN254 scalar field 

            // Initialize success as true
            let success := true

            {
                // Load vk_digest and num_instances of vk into memory
                mstore(0x05a0, 0x217af72668baf9c8807ea4cf68e93cb57d9c1a7285602c0abfdb7dc7a7030398) // vk_digest
                mstore(0x05c0, 0x000000000000000000000000000000000000000000000000000000000000004f) // num_instances

                // Check valid length of proof
                success := and(success, eq(0x2040, proof.length))

                // Check valid length of instances
                let num_instances := mload(NUM_INSTANCES_MPTR)
                success := and(success, eq(num_instances, instances.length))

                // Absorb vk diegst
                mstore(0x00, mload(VK_DIGEST_MPTR))

                // Read instances and witness commitments and generate challenges
                let hash_mptr := 0x20
                let instance_cptr := instances.offset
                for
                    { let instance_cptr_end := add(instance_cptr, mul(0x20, num_instances)) }
                    lt(instance_cptr, instance_cptr_end)
                    {}
                {
                    let instance := calldataload(instance_cptr)
                    success := and(success, lt(instance, r))
                    mstore(hash_mptr, instance)
                    instance_cptr := add(instance_cptr, 0x20)
                    hash_mptr := add(hash_mptr, 0x20)
                }

                let proof_cptr := proof.offset
                let challenge_mptr := CHALLENGE_MPTR

                // Phase 1
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0300) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)

                // Phase 2
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0580) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)
                challenge_mptr := squeeze_challenge_cont(challenge_mptr, r)

                // Phase 3
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0640) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)

                // Phase 4
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0200) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)

                // Read evaluations
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0f00) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    let eval := calldataload(proof_cptr)
                    success := and(success, lt(eval, r))
                    mstore(hash_mptr, eval)
                    proof_cptr := add(proof_cptr, 0x20)
                    hash_mptr := add(hash_mptr, 0x20)
                }

                // Read batch opening proof and generate challenges
                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)       // zeta
                challenge_mptr := squeeze_challenge_cont(challenge_mptr, r)                        // nu

                success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q) // W

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)       // mu

                success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q) // W'

                // Load full vk into memory
                mstore(0x05a0, 0x217af72668baf9c8807ea4cf68e93cb57d9c1a7285602c0abfdb7dc7a7030398) // vk_digest
                mstore(0x05c0, 0x000000000000000000000000000000000000000000000000000000000000004f) // num_instances
                mstore(0x05e0, 0x000000000000000000000000000000000000000000000000000000000000000c) // k
                mstore(0x0600, 0x3061482dfa038d0fb5b4c0b226194047a2616509f531d4fa3acdb77496c10001) // n_inv
                mstore(0x0620, 0x2f6122bbf1d35fdaa9953f60087a423238aa810773efee2a251aa6161f2e6ee6) // omega
                mstore(0x0640, 0x179c2392139def1b24f4e92b4bfba20a0fa885cb6bfc2f2cb92790e00237d0c0) // omega_inv
                mstore(0x0660, 0x28771071ab1633014eae27cfc16d5ebe08a8fe2fc9e85044e4a45f82c14cd825) // omega_inv_to_l
                mstore(0x0680, 0x0000000000000000000000000000000000000000000000000000000000000000) // has_accumulator
                mstore(0x06a0, 0x0000000000000000000000000000000000000000000000000000000000000000) // acc_offset
                mstore(0x06c0, 0x0000000000000000000000000000000000000000000000000000000000000000) // num_acc_limbs
                mstore(0x06e0, 0x0000000000000000000000000000000000000000000000000000000000000000) // num_acc_limb_bits
                mstore(0x0700, 0x0000000000000000000000000000000000000000000000000000000000000001) // g1_x
                mstore(0x0720, 0x0000000000000000000000000000000000000000000000000000000000000002) // g1_y
                mstore(0x0740, 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2) // g2_x_1
                mstore(0x0760, 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed) // g2_x_2
                mstore(0x0780, 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b) // g2_y_1
                mstore(0x07a0, 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa) // g2_y_2
                mstore(0x07c0, 0x186282957db913abd99f91db59fe69922e95040603ef44c0bd7aa3adeef8f5ac) // neg_s_g2_x_1
                mstore(0x07e0, 0x17944351223333f260ddc3b4af45191b856689eda9eab5cbcddbbe570ce860d2) // neg_s_g2_x_2
                mstore(0x0800, 0x06d971ff4a7467c3ec596ed6efc674572e32fd6f52b721f97e35b0b3d3546753) // neg_s_g2_y_1
                mstore(0x0820, 0x06ecdb9f9567f59ed2eee36e1e1d58797fd13cc97fafc2910f5e8a12f202fa9a) // neg_s_g2_y_2
                mstore(0x0840, 0x0664ef41cc0b062b1280211515a63662964537f8ce0c749dca895addd92b0663) // fixed_comms[0].x
                mstore(0x0860, 0x1598daf5f12fcd1f27768b0a313392af218420e5fc15a54ce66aa802cda9fa5b) // fixed_comms[0].y
                mstore(0x0880, 0x26b6099cbe3fffa074e8a76fd31d5e10aabd6b396406b27ef018db6c759c349b) // fixed_comms[1].x
                mstore(0x08a0, 0x22f345155662caab46494b6eed2d7573aa44f000f5a3759899f4bc0847e13e01) // fixed_comms[1].y
                mstore(0x08c0, 0x052669693850a7b66ce748a9357cea4af3c120d45adc96a3f51c21dce2006e09) // fixed_comms[2].x
                mstore(0x08e0, 0x284ec1e9db21d06f5557731d473e4699dc02210cc9a7bd08ffab5f93e861715b) // fixed_comms[2].y
                mstore(0x0900, 0x02f29b2d7b17de09a06be3ccba7370d4610d4d468345411ed121dfb3be0c88b9) // fixed_comms[3].x
                mstore(0x0920, 0x09e16cd5997d09e56cbe0603cab42fb471b6a35a3dec71b52990f97645b1be3e) // fixed_comms[3].y
                mstore(0x0940, 0x13bce136eb7fad9fb32615163b0c799c25d07b2ef87aaced9fa33ad185760dec) // fixed_comms[4].x
                mstore(0x0960, 0x02ed884305ec8bfb2edcd14210d8cf8900f549c79efe0b7f90fcdb82b493c5ab) // fixed_comms[4].y
                mstore(0x0980, 0x14eda040a7c41565bb3558d3382d695cc94af002861aa147eca8a11fa2750a50) // fixed_comms[5].x
                mstore(0x09a0, 0x136b1743d764af07be59985759483c7920b5451f25b3b27c9944eb6faa24c6b1) // fixed_comms[5].y
                mstore(0x09c0, 0x264beb6f2563ff0fdd25493d495c20f2a58300f507acb41b4c9253b8c240ccc3) // fixed_comms[6].x
                mstore(0x09e0, 0x22a5c1012fd6b8a37e8ac9621127aa103ac2e884d20a5c6d4e2bf3d16e796595) // fixed_comms[6].y
                mstore(0x0a00, 0x19db79dc9fa0b1be5c408254b023254856224fd632b5064f696a467942df52ce) // fixed_comms[7].x
                mstore(0x0a20, 0x0ab150d65778749076fdebfd25431554436ca7ffe4f3cb0b87a19d04265153e8) // fixed_comms[7].y
                mstore(0x0a40, 0x16e82c2374fb24ece058a1ff1e543383452e6caf7f4e779aa4eb33ad2e24d861) // fixed_comms[8].x
                mstore(0x0a60, 0x06fccfc0ff39d0e7aed21d26fef45fd1a54349a82d037661c1aaca1fe1a78a3e) // fixed_comms[8].y
                mstore(0x0a80, 0x27cfe88b797c4efaa00644da369b50727660aeb3cd29e8ba4ab25729e9e15a13) // fixed_comms[9].x
                mstore(0x0aa0, 0x1db7f177ef1639ed9b143f22f9b177e61c38c8b460c8aa09cce27c1f867c8489) // fixed_comms[9].y
                mstore(0x0ac0, 0x1434d9c819c36726e9aaabd11835354ce13cea7e54b3c19a2622211811e64b31) // fixed_comms[10].x
                mstore(0x0ae0, 0x1c5b3a7139485cee183a84d5aa3e61a75db4c1de2d57939bfba6dfd799dd5a1b) // fixed_comms[10].y
                mstore(0x0b00, 0x10e7a2b217a4034e2b4e0e3ef98653f33c63698f537fdda737dd14a94182deac) // fixed_comms[11].x
                mstore(0x0b20, 0x110d5b1e93b08f5554c0b249e3b731c3def7e56dc6dcc206998003b80013be9f) // fixed_comms[11].y
                mstore(0x0b40, 0x10e7a2b217a4034e2b4e0e3ef98653f33c63698f537fdda737dd14a94182deac) // fixed_comms[12].x
                mstore(0x0b60, 0x110d5b1e93b08f5554c0b249e3b731c3def7e56dc6dcc206998003b80013be9f) // fixed_comms[12].y
                mstore(0x0b80, 0x1d18162db24bd4b61b33931eba8640001f45b4cc60da5525945dc7471e49bf9f) // fixed_comms[13].x
                mstore(0x0ba0, 0x0c6b6f49ec227fb3203ca04788c63d7b2c99037f8ec97aee767786928758c0f0) // fixed_comms[13].y
                mstore(0x0bc0, 0x239e7aaef8da10b11a9d2bef1079f83ffb690ff5020da22e9e6b6ad5e15b55d9) // fixed_comms[14].x
                mstore(0x0be0, 0x0e8c83c17679b9f9a0d74cdcecb428d5f48cda9b8fd55940ace74ba2ca65864c) // fixed_comms[14].y
                mstore(0x0c00, 0x0979d70690c9c0f565c89c98684248471c00f7d8550e7ac52c0db24a8b0a7802) // fixed_comms[15].x
                mstore(0x0c20, 0x2aefc214f1dce0a318dbe4b2f890613e8b9df5317bb63aa8e3847027f5c734e1) // fixed_comms[15].y
                mstore(0x0c40, 0x2cabc5ea3acb3c240f12027bae91c4d79ec578070585b20a4c584468480472ff) // fixed_comms[16].x
                mstore(0x0c60, 0x154193c6924790b82267f7ac6dd2f67ff2eb88f3df7f97be94fa8d19bf8ec474) // fixed_comms[16].y
                mstore(0x0c80, 0x069c972a21156699c12950363a01c7bf0f53cb7559c2bc1718ade981a5401e77) // fixed_comms[17].x
                mstore(0x0ca0, 0x10efa3f74e29851ea27f2112b2c0c53d8f391019621a047a70963dea0a05d9a2) // fixed_comms[17].y
                mstore(0x0cc0, 0x16b09593f8043d1617855d0e037c20813087c542a648e0faf3e7f2a61015a1eb) // fixed_comms[18].x
                mstore(0x0ce0, 0x2159f3cf5906bf3ed5cdfc741428b330bc8a1835cfa91ba8383f1c867b80ef1f) // fixed_comms[18].y
                mstore(0x0d00, 0x14909871328c17e47730ffc3665c2d8fa7b869d5e2cfd3faf9076d8e9d3b55ba) // fixed_comms[19].x
                mstore(0x0d20, 0x1edb33ae7a4cfdcbc5b5e54694e3d73ceabd4bc9344268af5cb3236c35900130) // fixed_comms[19].y
                mstore(0x0d40, 0x0f5e14a2a6b136bd2a19b821ba830edee9693c210322624523f51c2f550e9d8d) // permutation_comms[0].x
                mstore(0x0d60, 0x302b05306a11d04aab8c3c499546ec56e527b5fab9b811ccc52949f7590d5cf5) // permutation_comms[0].y
                mstore(0x0d80, 0x0bf32b24b8ad5ed31f6b71f7d57d0f8caf26e022b2e75953837f1b5e86d0aa49) // permutation_comms[1].x
                mstore(0x0da0, 0x138986f9a91f216dd4c49d4b1bfb5342626ff3693483a62dec83e97d32a5c846) // permutation_comms[1].y
                mstore(0x0dc0, 0x2a09a497ac1fc93945db83ff40eb66fb55a4fa34ce8c28576513b43a904f73b0) // permutation_comms[2].x
                mstore(0x0de0, 0x28aa4d9283c803eba3b55578708f277729b753ca3b044369dc3a1b96293a7aad) // permutation_comms[2].y
                mstore(0x0e00, 0x075bf3fc12a565dfb01f0cda4fb0d5266aa9614dadef364dc14f91a4fdf7d906) // permutation_comms[3].x
                mstore(0x0e20, 0x06939afbb668fc2bcc50f2655cf874374624948dc9c4ef755c2ce0263e5703c2) // permutation_comms[3].y
                mstore(0x0e40, 0x2431b1ee410e7a5a943460042722cefa9cf5a4f0fd3c02a9072e92b9b12efefc) // permutation_comms[4].x
                mstore(0x0e60, 0x09429d96aa931d9be60aea2f571841c0b4a52b16020c18d9d8bb28c09ddaeeea) // permutation_comms[4].y
                mstore(0x0e80, 0x126a709a9cb54482546b35fbeafac32afa2cd4eaa78af69a970a3e598c4c7491) // permutation_comms[5].x
                mstore(0x0ea0, 0x26653075a249328ae8c53bab2ce77fdaf3a4c7de3811d9e950ed7e2b2f63fd7a) // permutation_comms[5].y
                mstore(0x0ec0, 0x129d7a6073c4a90d60d625ffffe1d37b330283a3adf9e07a0c7682e6f99b63a4) // permutation_comms[6].x
                mstore(0x0ee0, 0x032a1b9ca45e32d71cdf75bfce207c1d6040e87bf4d431b6ab911b50d90c88c7) // permutation_comms[6].y
                mstore(0x0f00, 0x01f8bcb58fdfb7e54463fb94235240287cb17ccae586d12e666134840935bd96) // permutation_comms[7].x
                mstore(0x0f20, 0x3005819b17e91a23d5180a9e1bd81f31c0ba1f57154cd8930688ad6b57a8a215) // permutation_comms[7].y
                mstore(0x0f40, 0x1b1d6b2d4735c58e21e824e2f6fd0432aa313155330cec886504cb2e22aa5592) // permutation_comms[8].x
                mstore(0x0f60, 0x2811c99650b4942474280cffa11c7c03153517b8cc1a56ead03ac15b13458751) // permutation_comms[8].y
                mstore(0x0f80, 0x0e5b492cc389a926911632786efefd167779f95a3cb644347870bf0b10694b7d) // permutation_comms[9].x
                mstore(0x0fa0, 0x2e488212b1b2f19511eb76935258e7afc20d16ae1c9fef237e9c8cc3357b3496) // permutation_comms[9].y
                mstore(0x0fc0, 0x04bdeb079f551e34198fe9792b36ba2b3699d73ad3a082a1709d47a765ca5c5e) // permutation_comms[10].x
                mstore(0x0fe0, 0x2baa3c607e54f835ada8f3ab08bb6672ec42c680c4a1a2726aff2e720ad5b9cf) // permutation_comms[10].y
                mstore(0x1000, 0x0879803cab568ba46b556a8c0d3d32acdb8ca3a77bb334eb02f0f1e4e00fd4aa) // permutation_comms[11].x
                mstore(0x1020, 0x086f9d43abf624dd9605bfe6ad00e5e59221ddd3dd293406814f1d446586df40) // permutation_comms[11].y
                mstore(0x1040, 0x1a4f7d505cb540e70c929a5b4fee83c30c39b554555f4299a84ab367eba9bbd8) // permutation_comms[12].x
                mstore(0x1060, 0x2cc89cb5757cce4fb51513f25169296be75bc76bf7502807b067e0c597f83e0b) // permutation_comms[12].y
                mstore(0x1080, 0x1db95de547a69903b66bd4c689a7aa53b007247e2cedd5ef114cad3509fea7ac) // permutation_comms[13].x
                mstore(0x10a0, 0x0a196e61f74e1fbb3fba09bb90b34c1873453e6cfbc05667bb0bf44934637f3a) // permutation_comms[13].y

                // Read accumulator from instances
                if mload(HAS_ACCUMULATOR_MPTR) {
                    let num_limbs := mload(NUM_ACC_LIMBS_MPTR)
                    let num_limb_bits := mload(NUM_ACC_LIMB_BITS_MPTR)

                    let cptr := add(instances.offset, mul(mload(ACC_OFFSET_MPTR), 0x20))
                    let lhs_y_off := mul(num_limbs, 0x20)
                    let rhs_x_off := mul(lhs_y_off, 2)
                    let rhs_y_off := mul(lhs_y_off, 3)
                    let lhs_x := calldataload(cptr)
                    let lhs_y := calldataload(add(cptr, lhs_y_off))
                    let rhs_x := calldataload(add(cptr, rhs_x_off))
                    let rhs_y := calldataload(add(cptr, rhs_y_off))
                    for
                        {
                            let cptr_end := add(cptr, mul(0x20, num_limbs))
                            let shift := num_limb_bits
                        }
                        lt(cptr, cptr_end)
                        {}
                    {
                        cptr := add(cptr, 0x20)
                        lhs_x := add(lhs_x, shl(shift, calldataload(cptr)))
                        lhs_y := add(lhs_y, shl(shift, calldataload(add(cptr, lhs_y_off))))
                        rhs_x := add(rhs_x, shl(shift, calldataload(add(cptr, rhs_x_off))))
                        rhs_y := add(rhs_y, shl(shift, calldataload(add(cptr, rhs_y_off))))
                        shift := add(shift, num_limb_bits)
                    }

                    success := and(success, eq(mulmod(lhs_y, lhs_y, q), addmod(mulmod(lhs_x, mulmod(lhs_x, lhs_x, q), q), 3, q)))
                    success := and(success, eq(mulmod(rhs_y, rhs_y, q), addmod(mulmod(rhs_x, mulmod(rhs_x, rhs_x, q), q), 3, q)))

                    mstore(ACC_LHS_X_MPTR, lhs_x)
                    mstore(ACC_LHS_Y_MPTR, lhs_y)
                    mstore(ACC_RHS_X_MPTR, rhs_x)
                    mstore(ACC_RHS_Y_MPTR, rhs_y)
                }

                pop(q)
            }

            // Revert earlier if anything from calldata is invalid
            if iszero(success) {
                revert(0, 0)
            }

            // Compute lagrange evaluations and instance evaluation
            {
                let k := mload(K_MPTR)
                let x := mload(X_MPTR)
                let x_n := x
                for
                    { let idx := 0 }
                    lt(idx, k)
                    { idx := add(idx, 1) }
                {
                    x_n := mulmod(x_n, x_n, r)
                }

                let omega := mload(OMEGA_MPTR)

                let mptr := X_N_MPTR
                let mptr_end := add(mptr, mul(0x20, add(mload(NUM_INSTANCES_MPTR), 6)))
                if iszero(mload(NUM_INSTANCES_MPTR)) {
                    mptr_end := add(mptr_end, 0x20)
                }
                for
                    { let pow_of_omega := mload(OMEGA_INV_TO_L_MPTR) }
                    lt(mptr, mptr_end)
                    { mptr := add(mptr, 0x20) }
                {
                    mstore(mptr, addmod(x, sub(r, pow_of_omega), r))
                    pow_of_omega := mulmod(pow_of_omega, omega, r)
                }
                let x_n_minus_1 := addmod(x_n, sub(r, 1), r)
                mstore(mptr_end, x_n_minus_1)
                success := batch_invert(success, X_N_MPTR, add(mptr_end, 0x20))

                mptr := X_N_MPTR
                let l_i_common := mulmod(x_n_minus_1, mload(N_INV_MPTR), r)
                for
                    { let pow_of_omega := mload(OMEGA_INV_TO_L_MPTR) }
                    lt(mptr, mptr_end)
                    { mptr := add(mptr, 0x20) }
                {
                    mstore(mptr, mulmod(l_i_common, mulmod(mload(mptr), pow_of_omega, r), r))
                    pow_of_omega := mulmod(pow_of_omega, omega, r)
                }

                let l_blind := mload(add(X_N_MPTR, 0x20))
                let l_i_cptr := add(X_N_MPTR, 0x40)
                for
                    { let l_i_cptr_end := add(X_N_MPTR, 0xc0) }
                    lt(l_i_cptr, l_i_cptr_end)
                    { l_i_cptr := add(l_i_cptr, 0x20) }
                {
                    l_blind := addmod(l_blind, mload(l_i_cptr), r)
                }

                let instance_eval := 0
                for
                    {
                        let instance_cptr := instances.offset
                        let instance_cptr_end := add(instance_cptr, mul(0x20, mload(NUM_INSTANCES_MPTR)))
                    }
                    lt(instance_cptr, instance_cptr_end)
                    {
                        instance_cptr := add(instance_cptr, 0x20)
                        l_i_cptr := add(l_i_cptr, 0x20)
                    }
                {
                    instance_eval := addmod(instance_eval, mulmod(mload(l_i_cptr), calldataload(instance_cptr), r), r)
                }

                let x_n_minus_1_inv := mload(mptr_end)
                let l_last := mload(X_N_MPTR)
                let l_0 := mload(add(X_N_MPTR, 0xc0))

                mstore(X_N_MPTR, x_n)
                mstore(X_N_MINUS_1_INV_MPTR, x_n_minus_1_inv)
                mstore(L_LAST_MPTR, l_last)
                mstore(L_BLIND_MPTR, l_blind)
                mstore(L_0_MPTR, l_0)
                mstore(INSTANCE_EVAL_MPTR, instance_eval)
            }

            // Compute quotient evavluation
            {
                let quotient_eval_numer
                let y := mload(Y_MPTR)
                {
                    let f_15 := calldataload(0x14c4)
                    let var0 := 0x2
                    let var1 := sub(R, f_15)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_15, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let var16 := 0x7
                    let var17 := addmod(var16, var1, R)
                    let var18 := mulmod(var15, var17, R)
                    let a_8 := calldataload(0x1224)
                    let a_0 := calldataload(0x1124)
                    let a_4 := calldataload(0x11a4)
                    let var19 := addmod(a_0, a_4, R)
                    let var20 := sub(R, var19)
                    let var21 := addmod(a_8, var20, R)
                    let var22 := mulmod(var18, var21, R)
                    quotient_eval_numer := var22
                }
                {
                    let f_16 := calldataload(0x14e4)
                    let var0 := 0x2
                    let var1 := sub(R, f_16)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_16, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_9 := calldataload(0x1244)
                    let a_1 := calldataload(0x1144)
                    let a_5 := calldataload(0x11c4)
                    let var16 := addmod(a_1, a_5, R)
                    let var17 := sub(R, var16)
                    let var18 := addmod(a_9, var17, R)
                    let var19 := mulmod(var15, var18, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var19, r)
                }
                {
                    let f_15 := calldataload(0x14c4)
                    let var0 := 0x1
                    let var1 := sub(R, f_15)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_15, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let var16 := 0x7
                    let var17 := addmod(var16, var1, R)
                    let var18 := mulmod(var15, var17, R)
                    let a_10 := calldataload(0x1264)
                    let a_2 := calldataload(0x1164)
                    let a_6 := calldataload(0x11e4)
                    let var19 := addmod(a_2, a_6, R)
                    let var20 := sub(R, var19)
                    let var21 := addmod(a_10, var20, R)
                    let var22 := mulmod(var18, var21, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var22, r)
                }
                {
                    let f_15 := calldataload(0x14c4)
                    let var0 := 0x1
                    let var1 := sub(R, f_15)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_15, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x4
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x5
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let var16 := 0x7
                    let var17 := addmod(var16, var1, R)
                    let var18 := mulmod(var15, var17, R)
                    let a_11 := calldataload(0x1284)
                    let a_3 := calldataload(0x1184)
                    let a_7 := calldataload(0x1204)
                    let var19 := addmod(a_3, a_7, R)
                    let var20 := sub(R, var19)
                    let var21 := addmod(a_11, var20, R)
                    let var22 := mulmod(var18, var21, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var22, r)
                }
                {
                    let f_15 := calldataload(0x14c4)
                    let var0 := 0x1
                    let var1 := sub(R, f_15)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_15, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let var16 := 0x7
                    let var17 := addmod(var16, var1, R)
                    let var18 := mulmod(var15, var17, R)
                    let a_8 := calldataload(0x1224)
                    let a_0 := calldataload(0x1124)
                    let a_4 := calldataload(0x11a4)
                    let var19 := mulmod(a_0, a_4, R)
                    let var20 := sub(R, var19)
                    let var21 := addmod(a_8, var20, R)
                    let var22 := mulmod(var18, var21, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var22, r)
                }
                {
                    let f_16 := calldataload(0x14e4)
                    let var0 := 0x1
                    let var1 := sub(R, f_16)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_16, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_9 := calldataload(0x1244)
                    let a_1 := calldataload(0x1144)
                    let a_5 := calldataload(0x11c4)
                    let var16 := mulmod(a_1, a_5, R)
                    let var17 := sub(R, var16)
                    let var18 := addmod(a_9, var17, R)
                    let var19 := mulmod(var15, var18, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var19, r)
                }
                {
                    let f_17 := calldataload(0x1504)
                    let var0 := 0x2
                    let var1 := sub(R, f_17)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_17, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_10 := calldataload(0x1264)
                    let a_2 := calldataload(0x1164)
                    let a_6 := calldataload(0x11e4)
                    let var16 := mulmod(a_2, a_6, R)
                    let var17 := sub(R, var16)
                    let var18 := addmod(a_10, var17, R)
                    let var19 := mulmod(var15, var18, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var19, r)
                }
                {
                    let f_18 := calldataload(0x1524)
                    let var0 := 0x2
                    let var1 := sub(R, f_18)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_18, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_11 := calldataload(0x1284)
                    let a_3 := calldataload(0x1184)
                    let a_7 := calldataload(0x1204)
                    let var7 := mulmod(a_3, a_7, R)
                    let var8 := sub(R, var7)
                    let var9 := addmod(a_11, var8, R)
                    let var10 := mulmod(var6, var9, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var10, r)
                }
                {
                    let f_15 := calldataload(0x14c4)
                    let var0 := 0x1
                    let var1 := sub(R, f_15)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_15, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let var16 := 0x7
                    let var17 := addmod(var16, var1, R)
                    let var18 := mulmod(var15, var17, R)
                    let a_8 := calldataload(0x1224)
                    let a_0 := calldataload(0x1124)
                    let a_4 := calldataload(0x11a4)
                    let var19 := sub(R, a_4)
                    let var20 := addmod(a_0, var19, R)
                    let var21 := sub(R, var20)
                    let var22 := addmod(a_8, var21, R)
                    let var23 := mulmod(var18, var22, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var23, r)
                }
                {
                    let f_16 := calldataload(0x14e4)
                    let var0 := 0x1
                    let var1 := sub(R, f_16)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_16, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_9 := calldataload(0x1244)
                    let a_1 := calldataload(0x1144)
                    let a_5 := calldataload(0x11c4)
                    let var16 := sub(R, a_5)
                    let var17 := addmod(a_1, var16, R)
                    let var18 := sub(R, var17)
                    let var19 := addmod(a_9, var18, R)
                    let var20 := mulmod(var15, var19, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var20, r)
                }
                {
                    let f_15 := calldataload(0x14c4)
                    let var0 := 0x1
                    let var1 := sub(R, f_15)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_15, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x4
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let var16 := 0x7
                    let var17 := addmod(var16, var1, R)
                    let var18 := mulmod(var15, var17, R)
                    let a_10 := calldataload(0x1264)
                    let a_2 := calldataload(0x1164)
                    let a_6 := calldataload(0x11e4)
                    let var19 := sub(R, a_6)
                    let var20 := addmod(a_2, var19, R)
                    let var21 := sub(R, var20)
                    let var22 := addmod(a_10, var21, R)
                    let var23 := mulmod(var18, var22, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var23, r)
                }
                {
                    let f_16 := calldataload(0x14e4)
                    let var0 := 0x1
                    let var1 := sub(R, f_16)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_16, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_11 := calldataload(0x1284)
                    let a_3 := calldataload(0x1184)
                    let a_7 := calldataload(0x1204)
                    let var16 := sub(R, a_7)
                    let var17 := addmod(a_3, var16, R)
                    let var18 := sub(R, var17)
                    let var19 := addmod(a_11, var18, R)
                    let var20 := mulmod(var15, var19, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var20, r)
                }
                {
                    let f_19 := calldataload(0x1544)
                    let var0 := 0x1
                    let var1 := sub(R, f_19)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_19, var2, R)
                    let a_8 := calldataload(0x1224)
                    let a_8_prev_1 := calldataload(0x12a4)
                    let var4 := 0x0
                    let a_0 := calldataload(0x1124)
                    let a_4 := calldataload(0x11a4)
                    let var5 := mulmod(a_0, a_4, R)
                    let var6 := addmod(var4, var5, R)
                    let a_1 := calldataload(0x1144)
                    let a_5 := calldataload(0x11c4)
                    let var7 := mulmod(a_1, a_5, R)
                    let var8 := addmod(var6, var7, R)
                    let var9 := addmod(a_8_prev_1, var8, R)
                    let var10 := sub(R, var9)
                    let var11 := addmod(a_8, var10, R)
                    let var12 := mulmod(var3, var11, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var12, r)
                }
                {
                    let f_17 := calldataload(0x1504)
                    let var0 := 0x1
                    let var1 := sub(R, f_17)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_17, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_10 := calldataload(0x1264)
                    let a_10_prev_1 := calldataload(0x12c4)
                    let var16 := 0x0
                    let a_2 := calldataload(0x1164)
                    let a_6 := calldataload(0x11e4)
                    let var17 := mulmod(a_2, a_6, R)
                    let var18 := addmod(var16, var17, R)
                    let a_3 := calldataload(0x1184)
                    let a_7 := calldataload(0x1204)
                    let var19 := mulmod(a_3, a_7, R)
                    let var20 := addmod(var18, var19, R)
                    let var21 := addmod(a_10_prev_1, var20, R)
                    let var22 := sub(R, var21)
                    let var23 := addmod(a_10, var22, R)
                    let var24 := mulmod(var15, var23, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var24, r)
                }
                {
                    let f_19 := calldataload(0x1544)
                    let var0 := 0x2
                    let var1 := sub(R, f_19)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_19, var2, R)
                    let a_8 := calldataload(0x1224)
                    let var4 := 0x0
                    let a_0 := calldataload(0x1124)
                    let a_4 := calldataload(0x11a4)
                    let var5 := mulmod(a_0, a_4, R)
                    let var6 := addmod(var4, var5, R)
                    let a_1 := calldataload(0x1144)
                    let a_5 := calldataload(0x11c4)
                    let var7 := mulmod(a_1, a_5, R)
                    let var8 := addmod(var6, var7, R)
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_8, var9, R)
                    let var11 := mulmod(var3, var10, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var11, r)
                }
                {
                    let f_17 := calldataload(0x1504)
                    let var0 := 0x1
                    let var1 := sub(R, f_17)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_17, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_10 := calldataload(0x1264)
                    let var16 := 0x0
                    let a_2 := calldataload(0x1164)
                    let a_6 := calldataload(0x11e4)
                    let var17 := mulmod(a_2, a_6, R)
                    let var18 := addmod(var16, var17, R)
                    let a_3 := calldataload(0x1184)
                    let a_7 := calldataload(0x1204)
                    let var19 := mulmod(a_3, a_7, R)
                    let var20 := addmod(var18, var19, R)
                    let var21 := sub(R, var20)
                    let var22 := addmod(a_10, var21, R)
                    let var23 := mulmod(var15, var22, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var23, r)
                }
                {
                    let f_15 := calldataload(0x14c4)
                    let var0 := 0x1
                    let var1 := sub(R, f_15)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_15, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x4
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x5
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let var16 := 0x6
                    let var17 := addmod(var16, var1, R)
                    let var18 := mulmod(var15, var17, R)
                    let a_8 := calldataload(0x1224)
                    let a_4 := calldataload(0x11a4)
                    let var19 := mulmod(var0, a_4, R)
                    let a_5 := calldataload(0x11c4)
                    let var20 := mulmod(var19, a_5, R)
                    let var21 := sub(R, var20)
                    let var22 := addmod(a_8, var21, R)
                    let var23 := mulmod(var18, var22, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var23, r)
                }
                {
                    let f_17 := calldataload(0x1504)
                    let var0 := 0x1
                    let var1 := sub(R, f_17)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_17, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x4
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x5
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_10 := calldataload(0x1264)
                    let a_6 := calldataload(0x11e4)
                    let var16 := mulmod(var0, a_6, R)
                    let a_7 := calldataload(0x1204)
                    let var17 := mulmod(var16, a_7, R)
                    let var18 := sub(R, var17)
                    let var19 := addmod(a_10, var18, R)
                    let var20 := mulmod(var15, var19, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var20, r)
                }
                {
                    let f_16 := calldataload(0x14e4)
                    let var0 := 0x1
                    let var1 := sub(R, f_16)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_16, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x4
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_8 := calldataload(0x1224)
                    let a_8_prev_1 := calldataload(0x12a4)
                    let a_4 := calldataload(0x11a4)
                    let var16 := mulmod(var0, a_4, R)
                    let a_5 := calldataload(0x11c4)
                    let var17 := mulmod(var16, a_5, R)
                    let var18 := mulmod(a_8_prev_1, var17, R)
                    let var19 := sub(R, var18)
                    let var20 := addmod(a_8, var19, R)
                    let var21 := mulmod(var15, var20, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var21, r)
                }
                {
                    let f_17 := calldataload(0x1504)
                    let var0 := 0x1
                    let var1 := sub(R, f_17)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_17, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x4
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_10 := calldataload(0x1264)
                    let a_10_prev_1 := calldataload(0x12c4)
                    let a_6 := calldataload(0x11e4)
                    let var16 := mulmod(var0, a_6, R)
                    let a_7 := calldataload(0x1204)
                    let var17 := mulmod(var16, a_7, R)
                    let var18 := mulmod(a_10_prev_1, var17, R)
                    let var19 := sub(R, var18)
                    let var20 := addmod(a_10, var19, R)
                    let var21 := mulmod(var15, var20, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var21, r)
                }
                {
                    let f_17 := calldataload(0x1504)
                    let var0 := 0x1
                    let var1 := sub(R, f_17)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_17, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x4
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x5
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x6
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_8 := calldataload(0x1224)
                    let var16 := 0x0
                    let a_4 := calldataload(0x11a4)
                    let var17 := addmod(var16, a_4, R)
                    let a_5 := calldataload(0x11c4)
                    let var18 := addmod(var17, a_5, R)
                    let var19 := sub(R, var18)
                    let var20 := addmod(a_8, var19, R)
                    let var21 := mulmod(var15, var20, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var21, r)
                }
                {
                    let f_18 := calldataload(0x1524)
                    let var0 := 0x1
                    let var1 := sub(R, f_18)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_18, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_10 := calldataload(0x1264)
                    let var7 := 0x0
                    let a_6 := calldataload(0x11e4)
                    let var8 := addmod(var7, a_6, R)
                    let a_7 := calldataload(0x1204)
                    let var9 := addmod(var8, a_7, R)
                    let var10 := sub(R, var9)
                    let var11 := addmod(a_10, var10, R)
                    let var12 := mulmod(var6, var11, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var12, r)
                }
                {
                    let f_16 := calldataload(0x14e4)
                    let var0 := 0x1
                    let var1 := sub(R, f_16)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_16, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let var7 := 0x3
                    let var8 := addmod(var7, var1, R)
                    let var9 := mulmod(var6, var8, R)
                    let var10 := 0x4
                    let var11 := addmod(var10, var1, R)
                    let var12 := mulmod(var9, var11, R)
                    let var13 := 0x5
                    let var14 := addmod(var13, var1, R)
                    let var15 := mulmod(var12, var14, R)
                    let a_8 := calldataload(0x1224)
                    let a_8_prev_1 := calldataload(0x12a4)
                    let var16 := 0x0
                    let a_4 := calldataload(0x11a4)
                    let var17 := addmod(var16, a_4, R)
                    let a_5 := calldataload(0x11c4)
                    let var18 := addmod(var17, a_5, R)
                    let var19 := addmod(a_8_prev_1, var18, R)
                    let var20 := sub(R, var19)
                    let var21 := addmod(a_8, var20, R)
                    let var22 := mulmod(var15, var21, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var22, r)
                }
                {
                    let f_18 := calldataload(0x1524)
                    let var0 := 0x1
                    let var1 := sub(R, f_18)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_18, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_10 := calldataload(0x1264)
                    let a_10_prev_1 := calldataload(0x12c4)
                    let var7 := 0x0
                    let a_6 := calldataload(0x11e4)
                    let var8 := addmod(var7, a_6, R)
                    let a_7 := calldataload(0x1204)
                    let var9 := addmod(var8, a_7, R)
                    let var10 := addmod(a_10_prev_1, var9, R)
                    let var11 := sub(R, var10)
                    let var12 := addmod(a_10, var11, R)
                    let var13 := mulmod(var6, var12, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var13, r)
                }
                {
                    let f_7 := calldataload(0x13c4)
                    let var0 := 0x0
                    let var1 := mulmod(f_7, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_8 := calldataload(0x13e4)
                    let var0 := 0x0
                    let var1 := mulmod(f_8, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_9 := calldataload(0x1404)
                    let var0 := 0x0
                    let var1 := mulmod(f_9, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_10 := calldataload(0x1424)
                    let var0 := 0x0
                    let var1 := mulmod(f_10, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_11 := calldataload(0x1444)
                    let var0 := 0x1
                    let a_4 := calldataload(0x11a4)
                    let var1 := 0x0
                    let var2 := sub(R, var1)
                    let var3 := addmod(a_4, var2, R)
                    let var4 := mulmod(var0, var3, R)
                    let var5 := sub(R, var0)
                    let var6 := addmod(a_4, var5, R)
                    let var7 := mulmod(var4, var6, R)
                    let var8 := 0x2
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_4, var9, R)
                    let var11 := mulmod(var7, var10, R)
                    let var12 := 0x3
                    let var13 := sub(R, var12)
                    let var14 := addmod(a_4, var13, R)
                    let var15 := mulmod(var11, var14, R)
                    let var16 := 0x4
                    let var17 := sub(R, var16)
                    let var18 := addmod(a_4, var17, R)
                    let var19 := mulmod(var15, var18, R)
                    let var20 := mulmod(f_11, var19, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var20, r)
                }
                {
                    let f_12 := calldataload(0x1464)
                    let var0 := 0x1
                    let a_5 := calldataload(0x11c4)
                    let var1 := 0x0
                    let var2 := sub(R, var1)
                    let var3 := addmod(a_5, var2, R)
                    let var4 := mulmod(var0, var3, R)
                    let var5 := sub(R, var0)
                    let var6 := addmod(a_5, var5, R)
                    let var7 := mulmod(var4, var6, R)
                    let var8 := 0x2
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_5, var9, R)
                    let var11 := mulmod(var7, var10, R)
                    let var12 := 0x3
                    let var13 := sub(R, var12)
                    let var14 := addmod(a_5, var13, R)
                    let var15 := mulmod(var11, var14, R)
                    let var16 := 0x4
                    let var17 := sub(R, var16)
                    let var18 := addmod(a_5, var17, R)
                    let var19 := mulmod(var15, var18, R)
                    let var20 := mulmod(f_12, var19, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var20, r)
                }
                {
                    let f_13 := calldataload(0x1484)
                    let var0 := 0x1
                    let a_6 := calldataload(0x11e4)
                    let var1 := 0x0
                    let var2 := sub(R, var1)
                    let var3 := addmod(a_6, var2, R)
                    let var4 := mulmod(var0, var3, R)
                    let var5 := sub(R, var0)
                    let var6 := addmod(a_6, var5, R)
                    let var7 := mulmod(var4, var6, R)
                    let var8 := 0x2
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_6, var9, R)
                    let var11 := mulmod(var7, var10, R)
                    let var12 := 0x3
                    let var13 := sub(R, var12)
                    let var14 := addmod(a_6, var13, R)
                    let var15 := mulmod(var11, var14, R)
                    let var16 := 0x4
                    let var17 := sub(R, var16)
                    let var18 := addmod(a_6, var17, R)
                    let var19 := mulmod(var15, var18, R)
                    let var20 := mulmod(f_13, var19, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var20, r)
                }
                {
                    let f_14 := calldataload(0x14a4)
                    let var0 := 0x1
                    let a_7 := calldataload(0x1204)
                    let var1 := 0x0
                    let var2 := sub(R, var1)
                    let var3 := addmod(a_7, var2, R)
                    let var4 := mulmod(var0, var3, R)
                    let var5 := sub(R, var0)
                    let var6 := addmod(a_7, var5, R)
                    let var7 := mulmod(var4, var6, R)
                    let var8 := 0x2
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_7, var9, R)
                    let var11 := mulmod(var7, var10, R)
                    let var12 := 0x3
                    let var13 := sub(R, var12)
                    let var14 := addmod(a_7, var13, R)
                    let var15 := mulmod(var11, var14, R)
                    let var16 := 0x4
                    let var17 := sub(R, var16)
                    let var18 := addmod(a_7, var17, R)
                    let var19 := mulmod(var15, var18, R)
                    let var20 := mulmod(f_14, var19, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var20, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := addmod(l_0, sub(R, mulmod(l_0, calldataload(0x1744), R)), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let perm_z_last := calldataload(0x17a4)
                    let eval := mulmod(mload(L_LAST_MPTR), addmod(mulmod(perm_z_last, perm_z_last, R), sub(R, perm_z_last), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let eval := mulmod(mload(L_0_MPTR), addmod(calldataload(0x17a4), sub(R, calldataload(0x1784)), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let gamma := mload(GAMMA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let lhs := calldataload(0x1764)
                    let rhs := calldataload(0x1744)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1124), mulmod(beta, calldataload(0x1584), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1144), mulmod(beta, calldataload(0x15a4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1164), mulmod(beta, calldataload(0x15c4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1184), mulmod(beta, calldataload(0x15e4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x11a4), mulmod(beta, calldataload(0x1604), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x11c4), mulmod(beta, calldataload(0x1624), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x11e4), mulmod(beta, calldataload(0x1644), R), R), gamma, R), R)
                    mstore(0x00, mulmod(beta, mload(X_MPTR), R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1124), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1144), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1164), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1184), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x11a4), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x11c4), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x11e4), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    let left_sub_right := addmod(lhs, sub(R, rhs), R)
                    let eval := addmod(left_sub_right, sub(R, mulmod(left_sub_right, addmod(mload(L_LAST_MPTR), mload(L_BLIND_MPTR), R), R)), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let gamma := mload(GAMMA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let lhs := calldataload(0x17c4)
                    let rhs := calldataload(0x17a4)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1204), mulmod(beta, calldataload(0x1664), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1224), mulmod(beta, calldataload(0x1684), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1244), mulmod(beta, calldataload(0x16a4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1264), mulmod(beta, calldataload(0x16c4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x1284), mulmod(beta, calldataload(0x16e4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x12e4), mulmod(beta, calldataload(0x1704), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(mload(INSTANCE_EVAL_MPTR), mulmod(beta, calldataload(0x1724), R), R), gamma, R), R)
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1204), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1224), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1244), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1264), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x1284), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x12e4), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(mload(INSTANCE_EVAL_MPTR), mload(0x00), R), gamma, R), R)
                    let left_sub_right := addmod(lhs, sub(R, rhs), R)
                    let eval := addmod(left_sub_right, sub(R, mulmod(left_sub_right, addmod(mload(L_LAST_MPTR), mload(L_BLIND_MPTR), R), R)), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x17e4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x17e4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_1 := calldataload(0x1304)
                        table := f_1
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_7 := calldataload(0x13c4)
                        let var0 := 0x1
                        let var1 := mulmod(f_7, var0, R)
                        let a_0 := calldataload(0x1124)
                        let var2 := mulmod(var1, a_0, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000000
                        let var6 := mulmod(var4, var5, R)
                        let var7 := addmod(var2, var6, R)
                        input_0 := var7
                        input_0 := addmod(input_0, beta, R)
                    }
                    let input_1
                    {
                        let f_8 := calldataload(0x13e4)
                        let var0 := 0x1
                        let var1 := mulmod(f_8, var0, R)
                        let a_1 := calldataload(0x1144)
                        let var2 := mulmod(var1, a_1, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000000
                        let var6 := mulmod(var4, var5, R)
                        let var7 := addmod(var2, var6, R)
                        input_1 := var7
                        input_1 := addmod(input_1, beta, R)
                    }
                    let input_2
                    {
                        let f_9 := calldataload(0x1404)
                        let var0 := 0x1
                        let var1 := mulmod(f_9, var0, R)
                        let a_2 := calldataload(0x1164)
                        let var2 := mulmod(var1, a_2, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000000
                        let var6 := mulmod(var4, var5, R)
                        let var7 := addmod(var2, var6, R)
                        input_2 := var7
                        input_2 := addmod(input_2, beta, R)
                    }
                    let lhs
                    let rhs
                    {
                        let tmp := input_1
                        tmp := mulmod(tmp, input_2, R)
                        rhs := addmod(rhs, tmp, R)
                    }
                    {
                        let tmp := input_0
                        tmp := mulmod(tmp, input_2, R)
                        rhs := addmod(rhs, tmp, R)
                    }
                    {
                        let tmp := input_0
                        tmp := mulmod(tmp, input_1, R)
                        rhs := addmod(rhs, tmp, R)
                        rhs := mulmod(rhs, table, R)
                    }
                    {
                        let tmp := input_0
                        tmp := mulmod(tmp, input_1, R)
                        tmp := mulmod(tmp, input_2, R)
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1824), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1804), sub(R, calldataload(0x17e4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1844), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1844), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_1 := calldataload(0x1304)
                        table := f_1
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_10 := calldataload(0x1424)
                        let var0 := 0x1
                        let var1 := mulmod(f_10, var0, R)
                        let a_3 := calldataload(0x1184)
                        let var2 := mulmod(var1, a_3, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000000
                        let var6 := mulmod(var4, var5, R)
                        let var7 := addmod(var2, var6, R)
                        input_0 := var7
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1884), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1864), sub(R, calldataload(0x1844)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x18a4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x18a4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_2 := calldataload(0x1324)
                        table := f_2
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_11 := calldataload(0x1444)
                        let var0 := 0x1
                        let a_4 := calldataload(0x11a4)
                        let var1 := sub(R, a_4)
                        let var2 := addmod(var0, var1, R)
                        let var3 := mulmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := 0x2
                        let var6 := addmod(var5, var1, R)
                        let var7 := mulmod(var0, var6, R)
                        let var8 := 0x3
                        let var9 := addmod(var8, var1, R)
                        let var10 := mulmod(var0, var9, R)
                        let var11 := 0x4
                        let var12 := addmod(var11, var1, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var10, var13, R)
                        let var15 := mulmod(var7, var14, R)
                        let var16 := mulmod(var4, var15, R)
                        let var17 := mulmod(f_11, var16, R)
                        let a_0 := calldataload(0x1124)
                        let var18 := mulmod(var17, a_0, R)
                        let var19 := 0x18
                        let var20 := sub(R, var17)
                        let var21 := addmod(var19, var20, R)
                        let var22 := 0x0
                        let var23 := mulmod(var21, var22, R)
                        let var24 := addmod(var18, var23, R)
                        input_0 := var24
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x18e4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x18c4), sub(R, calldataload(0x18a4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1904), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1904), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_2 := calldataload(0x1324)
                        table := f_2
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_12 := calldataload(0x1464)
                        let var0 := 0x1
                        let a_5 := calldataload(0x11c4)
                        let var1 := sub(R, a_5)
                        let var2 := addmod(var0, var1, R)
                        let var3 := mulmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := 0x2
                        let var6 := addmod(var5, var1, R)
                        let var7 := mulmod(var0, var6, R)
                        let var8 := 0x3
                        let var9 := addmod(var8, var1, R)
                        let var10 := mulmod(var0, var9, R)
                        let var11 := 0x4
                        let var12 := addmod(var11, var1, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var10, var13, R)
                        let var15 := mulmod(var7, var14, R)
                        let var16 := mulmod(var4, var15, R)
                        let var17 := mulmod(f_12, var16, R)
                        let a_1 := calldataload(0x1144)
                        let var18 := mulmod(var17, a_1, R)
                        let var19 := 0x18
                        let var20 := sub(R, var17)
                        let var21 := addmod(var19, var20, R)
                        let var22 := 0x0
                        let var23 := mulmod(var21, var22, R)
                        let var24 := addmod(var18, var23, R)
                        input_0 := var24
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1944), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1924), sub(R, calldataload(0x1904)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1964), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1964), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_2 := calldataload(0x1324)
                        table := f_2
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_13 := calldataload(0x1484)
                        let var0 := 0x1
                        let a_6 := calldataload(0x11e4)
                        let var1 := sub(R, a_6)
                        let var2 := addmod(var0, var1, R)
                        let var3 := mulmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := 0x2
                        let var6 := addmod(var5, var1, R)
                        let var7 := mulmod(var0, var6, R)
                        let var8 := 0x3
                        let var9 := addmod(var8, var1, R)
                        let var10 := mulmod(var0, var9, R)
                        let var11 := 0x4
                        let var12 := addmod(var11, var1, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var10, var13, R)
                        let var15 := mulmod(var7, var14, R)
                        let var16 := mulmod(var4, var15, R)
                        let var17 := mulmod(f_13, var16, R)
                        let a_2 := calldataload(0x1164)
                        let var18 := mulmod(var17, a_2, R)
                        let var19 := 0x18
                        let var20 := sub(R, var17)
                        let var21 := addmod(var19, var20, R)
                        let var22 := 0x0
                        let var23 := mulmod(var21, var22, R)
                        let var24 := addmod(var18, var23, R)
                        input_0 := var24
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x19a4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1984), sub(R, calldataload(0x1964)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x19c4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x19c4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_2 := calldataload(0x1324)
                        table := f_2
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_14 := calldataload(0x14a4)
                        let var0 := 0x1
                        let a_7 := calldataload(0x1204)
                        let var1 := sub(R, a_7)
                        let var2 := addmod(var0, var1, R)
                        let var3 := mulmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := 0x2
                        let var6 := addmod(var5, var1, R)
                        let var7 := mulmod(var0, var6, R)
                        let var8 := 0x3
                        let var9 := addmod(var8, var1, R)
                        let var10 := mulmod(var0, var9, R)
                        let var11 := 0x4
                        let var12 := addmod(var11, var1, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var10, var13, R)
                        let var15 := mulmod(var7, var14, R)
                        let var16 := mulmod(var4, var15, R)
                        let var17 := mulmod(f_14, var16, R)
                        let a_3 := calldataload(0x1184)
                        let var18 := mulmod(var17, a_3, R)
                        let var19 := 0x18
                        let var20 := sub(R, var17)
                        let var21 := addmod(var19, var20, R)
                        let var22 := 0x0
                        let var23 := mulmod(var21, var22, R)
                        let var24 := addmod(var18, var23, R)
                        input_0 := var24
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1a04), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x19e4), sub(R, calldataload(0x19c4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1a24), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1a24), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_3 := calldataload(0x1344)
                        table := f_3
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_11 := calldataload(0x1444)
                        let var0 := 0x1
                        let a_4 := calldataload(0x11a4)
                        let var1 := mulmod(var0, a_4, R)
                        let var2 := mulmod(var1, var0, R)
                        let var3 := 0x2
                        let var4 := sub(R, a_4)
                        let var5 := addmod(var3, var4, R)
                        let var6 := mulmod(var0, var5, R)
                        let var7 := 0x3
                        let var8 := addmod(var7, var4, R)
                        let var9 := mulmod(var0, var8, R)
                        let var10 := 0x4
                        let var11 := addmod(var10, var4, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var9, var12, R)
                        let var14 := mulmod(var6, var13, R)
                        let var15 := mulmod(var2, var14, R)
                        let var16 := mulmod(f_11, var15, R)
                        let a_0 := calldataload(0x1124)
                        let var17 := mulmod(var16, a_0, R)
                        let var18 := 0x6
                        let var19 := sub(R, var16)
                        let var20 := addmod(var18, var19, R)
                        let var21 := 0xff8
                        let var22 := mulmod(var20, var21, R)
                        let var23 := addmod(var17, var22, R)
                        input_0 := var23
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1a64), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1a44), sub(R, calldataload(0x1a24)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1a84), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1a84), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_3 := calldataload(0x1344)
                        table := f_3
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_12 := calldataload(0x1464)
                        let var0 := 0x1
                        let a_5 := calldataload(0x11c4)
                        let var1 := mulmod(var0, a_5, R)
                        let var2 := mulmod(var1, var0, R)
                        let var3 := 0x2
                        let var4 := sub(R, a_5)
                        let var5 := addmod(var3, var4, R)
                        let var6 := mulmod(var0, var5, R)
                        let var7 := 0x3
                        let var8 := addmod(var7, var4, R)
                        let var9 := mulmod(var0, var8, R)
                        let var10 := 0x4
                        let var11 := addmod(var10, var4, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var9, var12, R)
                        let var14 := mulmod(var6, var13, R)
                        let var15 := mulmod(var2, var14, R)
                        let var16 := mulmod(f_12, var15, R)
                        let a_1 := calldataload(0x1144)
                        let var17 := mulmod(var16, a_1, R)
                        let var18 := 0x6
                        let var19 := sub(R, var16)
                        let var20 := addmod(var18, var19, R)
                        let var21 := 0xff8
                        let var22 := mulmod(var20, var21, R)
                        let var23 := addmod(var17, var22, R)
                        input_0 := var23
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1ac4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1aa4), sub(R, calldataload(0x1a84)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1ae4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1ae4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_3 := calldataload(0x1344)
                        table := f_3
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_13 := calldataload(0x1484)
                        let var0 := 0x1
                        let a_6 := calldataload(0x11e4)
                        let var1 := mulmod(var0, a_6, R)
                        let var2 := mulmod(var1, var0, R)
                        let var3 := 0x2
                        let var4 := sub(R, a_6)
                        let var5 := addmod(var3, var4, R)
                        let var6 := mulmod(var0, var5, R)
                        let var7 := 0x3
                        let var8 := addmod(var7, var4, R)
                        let var9 := mulmod(var0, var8, R)
                        let var10 := 0x4
                        let var11 := addmod(var10, var4, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var9, var12, R)
                        let var14 := mulmod(var6, var13, R)
                        let var15 := mulmod(var2, var14, R)
                        let var16 := mulmod(f_13, var15, R)
                        let a_2 := calldataload(0x1164)
                        let var17 := mulmod(var16, a_2, R)
                        let var18 := 0x6
                        let var19 := sub(R, var16)
                        let var20 := addmod(var18, var19, R)
                        let var21 := 0xff8
                        let var22 := mulmod(var20, var21, R)
                        let var23 := addmod(var17, var22, R)
                        input_0 := var23
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1b24), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1b04), sub(R, calldataload(0x1ae4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1b44), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1b44), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_3 := calldataload(0x1344)
                        table := f_3
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_14 := calldataload(0x14a4)
                        let var0 := 0x1
                        let a_7 := calldataload(0x1204)
                        let var1 := mulmod(var0, a_7, R)
                        let var2 := mulmod(var1, var0, R)
                        let var3 := 0x2
                        let var4 := sub(R, a_7)
                        let var5 := addmod(var3, var4, R)
                        let var6 := mulmod(var0, var5, R)
                        let var7 := 0x3
                        let var8 := addmod(var7, var4, R)
                        let var9 := mulmod(var0, var8, R)
                        let var10 := 0x4
                        let var11 := addmod(var10, var4, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var9, var12, R)
                        let var14 := mulmod(var6, var13, R)
                        let var15 := mulmod(var2, var14, R)
                        let var16 := mulmod(f_14, var15, R)
                        let a_3 := calldataload(0x1184)
                        let var17 := mulmod(var16, a_3, R)
                        let var18 := 0x6
                        let var19 := sub(R, var16)
                        let var20 := addmod(var18, var19, R)
                        let var21 := 0xff8
                        let var22 := mulmod(var20, var21, R)
                        let var23 := addmod(var17, var22, R)
                        input_0 := var23
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1b84), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1b64), sub(R, calldataload(0x1b44)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1ba4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1ba4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_4 := calldataload(0x1364)
                        table := f_4
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_11 := calldataload(0x1444)
                        let var0 := 0x1
                        let a_4 := calldataload(0x11a4)
                        let var1 := mulmod(var0, a_4, R)
                        let var2 := sub(R, a_4)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x3
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var8, var11, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_11, var14, R)
                        let a_0 := calldataload(0x1124)
                        let var16 := mulmod(var15, a_0, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593effffffd
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x1ff0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1be4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1bc4), sub(R, calldataload(0x1ba4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1c04), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1c04), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_4 := calldataload(0x1364)
                        table := f_4
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_12 := calldataload(0x1464)
                        let var0 := 0x1
                        let a_5 := calldataload(0x11c4)
                        let var1 := mulmod(var0, a_5, R)
                        let var2 := sub(R, a_5)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x3
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var8, var11, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_12, var14, R)
                        let a_1 := calldataload(0x1144)
                        let var16 := mulmod(var15, a_1, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593effffffd
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x1ff0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1c44), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1c24), sub(R, calldataload(0x1c04)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1c64), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1c64), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_4 := calldataload(0x1364)
                        table := f_4
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_13 := calldataload(0x1484)
                        let var0 := 0x1
                        let a_6 := calldataload(0x11e4)
                        let var1 := mulmod(var0, a_6, R)
                        let var2 := sub(R, a_6)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x3
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var8, var11, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_13, var14, R)
                        let a_2 := calldataload(0x1164)
                        let var16 := mulmod(var15, a_2, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593effffffd
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x1ff0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1ca4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1c84), sub(R, calldataload(0x1c64)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1cc4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1cc4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_4 := calldataload(0x1364)
                        table := f_4
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_14 := calldataload(0x14a4)
                        let var0 := 0x1
                        let a_7 := calldataload(0x1204)
                        let var1 := mulmod(var0, a_7, R)
                        let var2 := sub(R, a_7)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x3
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var8, var11, R)
                        let var13 := mulmod(var0, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_14, var14, R)
                        let a_3 := calldataload(0x1184)
                        let var16 := mulmod(var15, a_3, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593effffffd
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x1ff0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1d04), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1ce4), sub(R, calldataload(0x1cc4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1d24), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1d24), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_5 := calldataload(0x1384)
                        table := f_5
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_11 := calldataload(0x1444)
                        let var0 := 0x1
                        let a_4 := calldataload(0x11a4)
                        let var1 := mulmod(var0, a_4, R)
                        let var2 := sub(R, a_4)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_11, var14, R)
                        let a_0 := calldataload(0x1124)
                        let var16 := mulmod(var15, a_0, R)
                        let var17 := 0x6
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x2fe8
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1d64), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1d44), sub(R, calldataload(0x1d24)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1d84), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1d84), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_5 := calldataload(0x1384)
                        table := f_5
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_12 := calldataload(0x1464)
                        let var0 := 0x1
                        let a_5 := calldataload(0x11c4)
                        let var1 := mulmod(var0, a_5, R)
                        let var2 := sub(R, a_5)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_12, var14, R)
                        let a_1 := calldataload(0x1144)
                        let var16 := mulmod(var15, a_1, R)
                        let var17 := 0x6
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x2fe8
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1dc4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1da4), sub(R, calldataload(0x1d84)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1de4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1de4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_5 := calldataload(0x1384)
                        table := f_5
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_13 := calldataload(0x1484)
                        let var0 := 0x1
                        let a_6 := calldataload(0x11e4)
                        let var1 := mulmod(var0, a_6, R)
                        let var2 := sub(R, a_6)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_13, var14, R)
                        let a_2 := calldataload(0x1164)
                        let var16 := mulmod(var15, a_2, R)
                        let var17 := 0x6
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x2fe8
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1e24), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1e04), sub(R, calldataload(0x1de4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1e44), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1e44), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_5 := calldataload(0x1384)
                        table := f_5
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_14 := calldataload(0x14a4)
                        let var0 := 0x1
                        let a_7 := calldataload(0x1204)
                        let var1 := mulmod(var0, a_7, R)
                        let var2 := sub(R, a_7)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x4
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var0, var11, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_14, var14, R)
                        let a_3 := calldataload(0x1184)
                        let var16 := mulmod(var15, a_3, R)
                        let var17 := 0x6
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x2fe8
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1e84), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1e64), sub(R, calldataload(0x1e44)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1ea4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1ea4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_6 := calldataload(0x13a4)
                        table := f_6
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_11 := calldataload(0x1444)
                        let var0 := 0x1
                        let a_4 := calldataload(0x11a4)
                        let var1 := mulmod(var0, a_4, R)
                        let var2 := sub(R, a_4)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x3
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var11, var0, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_11, var14, R)
                        let a_0 := calldataload(0x1124)
                        let var16 := mulmod(var15, a_0, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffffe9
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x3fe0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1ee4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1ec4), sub(R, calldataload(0x1ea4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1f04), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1f04), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_6 := calldataload(0x13a4)
                        table := f_6
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_12 := calldataload(0x1464)
                        let var0 := 0x1
                        let a_5 := calldataload(0x11c4)
                        let var1 := mulmod(var0, a_5, R)
                        let var2 := sub(R, a_5)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x3
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var11, var0, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_12, var14, R)
                        let a_1 := calldataload(0x1144)
                        let var16 := mulmod(var15, a_1, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffffe9
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x3fe0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1f44), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1f24), sub(R, calldataload(0x1f04)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1f64), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1f64), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_6 := calldataload(0x13a4)
                        table := f_6
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_13 := calldataload(0x1484)
                        let var0 := 0x1
                        let a_6 := calldataload(0x11e4)
                        let var1 := mulmod(var0, a_6, R)
                        let var2 := sub(R, a_6)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x3
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var11, var0, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_13, var14, R)
                        let a_2 := calldataload(0x1164)
                        let var16 := mulmod(var15, a_2, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffffe9
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x3fe0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x1fa4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1f84), sub(R, calldataload(0x1f64)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x1fc4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x1fc4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_6 := calldataload(0x13a4)
                        table := f_6
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_14 := calldataload(0x14a4)
                        let var0 := 0x1
                        let a_7 := calldataload(0x1204)
                        let var1 := mulmod(var0, a_7, R)
                        let var2 := sub(R, a_7)
                        let var3 := addmod(var0, var2, R)
                        let var4 := mulmod(var0, var3, R)
                        let var5 := mulmod(var1, var4, R)
                        let var6 := 0x2
                        let var7 := addmod(var6, var2, R)
                        let var8 := mulmod(var0, var7, R)
                        let var9 := 0x3
                        let var10 := addmod(var9, var2, R)
                        let var11 := mulmod(var0, var10, R)
                        let var12 := mulmod(var11, var0, R)
                        let var13 := mulmod(var8, var12, R)
                        let var14 := mulmod(var5, var13, R)
                        let var15 := mulmod(f_14, var14, R)
                        let a_3 := calldataload(0x1184)
                        let var16 := mulmod(var15, a_3, R)
                        let var17 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffffe9
                        let var18 := sub(R, var15)
                        let var19 := addmod(var17, var18, R)
                        let var20 := 0x3fe0
                        let var21 := mulmod(var19, var20, R)
                        let var22 := addmod(var16, var21, R)
                        input_0 := var22
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x2004), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x1fe4), sub(R, calldataload(0x1fc4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }

                pop(y)

                let quotient_eval := mulmod(quotient_eval_numer, mload(X_N_MINUS_1_INV_MPTR), r)
                mstore(QUOTIENT_EVAL_MPTR, quotient_eval)
            }

            // Compute quotient commitment
            {
                mstore(0x00, calldataload(LAST_QUOTIENT_X_CPTR))
                mstore(0x20, calldataload(add(LAST_QUOTIENT_X_CPTR, 0x20)))
                let x_n := mload(X_N_MPTR)
                for
                    {
                        let cptr := sub(LAST_QUOTIENT_X_CPTR, 0x40)
                        let cptr_end := sub(FIRST_QUOTIENT_X_CPTR, 0x40)
                    }
                    lt(cptr_end, cptr)
                    {}
                {
                    success := ec_mul_acc(success, x_n)
                    success := ec_add_acc(success, calldataload(cptr), calldataload(add(cptr, 0x20)))
                    cptr := sub(cptr, 0x40)
                }
                mstore(QUOTIENT_X_MPTR, mload(0x00))
                mstore(QUOTIENT_Y_MPTR, mload(0x20))
            }

            // Compute pairing lhs and rhs
            {
                {
                    let x := mload(X_MPTR)
                    let omega := mload(OMEGA_MPTR)
                    let omega_inv := mload(OMEGA_INV_MPTR)
                    let x_pow_of_omega := mulmod(x, omega, R)
                    mstore(0x0360, x_pow_of_omega)
                    mstore(0x0340, x)
                    x_pow_of_omega := mulmod(x, omega_inv, R)
                    mstore(0x0320, x_pow_of_omega)
                    x_pow_of_omega := mulmod(x_pow_of_omega, omega_inv, R)
                    x_pow_of_omega := mulmod(x_pow_of_omega, omega_inv, R)
                    x_pow_of_omega := mulmod(x_pow_of_omega, omega_inv, R)
                    x_pow_of_omega := mulmod(x_pow_of_omega, omega_inv, R)
                    x_pow_of_omega := mulmod(x_pow_of_omega, omega_inv, R)
                    mstore(0x0300, x_pow_of_omega)
                }
                {
                    let mu := mload(MU_MPTR)
                    for
                        {
                            let mptr := 0x0380
                            let mptr_end := 0x0400
                            let point_mptr := 0x0300
                        }
                        lt(mptr, mptr_end)
                        {
                            mptr := add(mptr, 0x20)
                            point_mptr := add(point_mptr, 0x20)
                        }
                    {
                        mstore(mptr, addmod(mu, sub(R, mload(point_mptr)), R))
                    }
                    let s
                    s := mload(0x03c0)
                    mstore(0x0400, s)
                    let diff
                    diff := mload(0x0380)
                    diff := mulmod(diff, mload(0x03a0), R)
                    diff := mulmod(diff, mload(0x03e0), R)
                    mstore(0x0420, diff)
                    mstore(0x00, diff)
                    diff := mload(0x0380)
                    diff := mulmod(diff, mload(0x03e0), R)
                    mstore(0x0440, diff)
                    diff := mload(0x03a0)
                    mstore(0x0460, diff)
                    diff := mload(0x0380)
                    diff := mulmod(diff, mload(0x03a0), R)
                    mstore(0x0480, diff)
                }
                {
                    let point_2 := mload(0x0340)
                    let coeff
                    coeff := 1
                    coeff := mulmod(coeff, mload(0x03c0), R)
                    mstore(0x20, coeff)
                }
                {
                    let point_1 := mload(0x0320)
                    let point_2 := mload(0x0340)
                    let coeff
                    coeff := addmod(point_1, sub(R, point_2), R)
                    coeff := mulmod(coeff, mload(0x03a0), R)
                    mstore(0x40, coeff)
                    coeff := addmod(point_2, sub(R, point_1), R)
                    coeff := mulmod(coeff, mload(0x03c0), R)
                    mstore(0x60, coeff)
                }
                {
                    let point_0 := mload(0x0300)
                    let point_2 := mload(0x0340)
                    let point_3 := mload(0x0360)
                    let coeff
                    coeff := addmod(point_0, sub(R, point_2), R)
                    coeff := mulmod(coeff, addmod(point_0, sub(R, point_3), R), R)
                    coeff := mulmod(coeff, mload(0x0380), R)
                    mstore(0x80, coeff)
                    coeff := addmod(point_2, sub(R, point_0), R)
                    coeff := mulmod(coeff, addmod(point_2, sub(R, point_3), R), R)
                    coeff := mulmod(coeff, mload(0x03c0), R)
                    mstore(0xa0, coeff)
                    coeff := addmod(point_3, sub(R, point_0), R)
                    coeff := mulmod(coeff, addmod(point_3, sub(R, point_2), R), R)
                    coeff := mulmod(coeff, mload(0x03e0), R)
                    mstore(0xc0, coeff)
                }
                {
                    let point_2 := mload(0x0340)
                    let point_3 := mload(0x0360)
                    let coeff
                    coeff := addmod(point_2, sub(R, point_3), R)
                    coeff := mulmod(coeff, mload(0x03c0), R)
                    mstore(0xe0, coeff)
                    coeff := addmod(point_3, sub(R, point_2), R)
                    coeff := mulmod(coeff, mload(0x03e0), R)
                    mstore(0x0100, coeff)
                }
                {
                    success := batch_invert(success, 0, 0x0120)
                    let diff_0_inv := mload(0x00)
                    mstore(0x0420, diff_0_inv)
                    for
                        {
                            let mptr := 0x0440
                            let mptr_end := 0x04a0
                        }
                        lt(mptr, mptr_end)
                        { mptr := add(mptr, 0x20) }
                    {
                        mstore(mptr, mulmod(mload(mptr), diff_0_inv, R))
                    }
                }
                {
                    let coeff := mload(0x20)
                    let zeta := mload(ZETA_MPTR)
                    let r_eval := 0
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1564), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, mload(QUOTIENT_EVAL_MPTR), R), R)
                    for
                        {
                            let mptr := 0x1724
                            let mptr_end := 0x1564
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x20) }
                    {
                        r_eval := addmod(mulmod(r_eval, zeta, R), mulmod(coeff, calldataload(mptr), R), R)
                    }
                    for
                        {
                            let mptr := 0x1544
                            let mptr_end := 0x12c4
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x20) }
                    {
                        r_eval := addmod(mulmod(r_eval, zeta, R), mulmod(coeff, calldataload(mptr), R), R)
                    }
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x2004), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1fa4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1f44), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1ee4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1e84), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1e24), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1dc4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1d64), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1d04), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1ca4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1c44), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1be4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1b84), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1b24), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1ac4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1a64), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1a04), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x19a4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1944), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x18e4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1884), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1824), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1284), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x1244), R), R)
                    for
                        {
                            let mptr := 0x1204
                            let mptr_end := 0x1104
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x20) }
                    {
                        r_eval := addmod(mulmod(r_eval, zeta, R), mulmod(coeff, calldataload(mptr), R), R)
                    }
                    mstore(0x04a0, r_eval)
                }
                {
                    let zeta := mload(ZETA_MPTR)
                    let r_eval := 0
                    r_eval := addmod(r_eval, mulmod(mload(0x40), calldataload(0x12c4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x60), calldataload(0x1264), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0x40), calldataload(0x12a4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x60), calldataload(0x1224), R), R)
                    r_eval := mulmod(r_eval, mload(0x0440), R)
                    mstore(0x04c0, r_eval)
                }
                {
                    let zeta := mload(ZETA_MPTR)
                    let r_eval := 0
                    r_eval := addmod(r_eval, mulmod(mload(0x80), calldataload(0x1784), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0xa0), calldataload(0x1744), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0xc0), calldataload(0x1764), R), R)
                    r_eval := mulmod(r_eval, mload(0x0460), R)
                    mstore(0x04e0, r_eval)
                }
                {
                    let zeta := mload(ZETA_MPTR)
                    let r_eval := 0
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1fc4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1fe4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1f64), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1f84), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1f04), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1f24), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1ea4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1ec4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1e44), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1e64), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1de4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1e04), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1d84), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1da4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1d24), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1d44), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1cc4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1ce4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1c64), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1c84), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1c04), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1c24), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1ba4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1bc4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1b44), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1b64), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1ae4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1b04), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1a84), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1aa4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1a24), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1a44), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x19c4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x19e4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1964), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1984), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1904), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1924), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x18a4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x18c4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x1844), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1864), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x17e4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x1804), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x17a4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x17c4), R), R)
                    r_eval := mulmod(r_eval, mload(0x0480), R)
                    mstore(0x0500, r_eval)
                }
                {
                    let sum := mload(0x20)
                    mstore(0x0520, sum)
                }
                {
                    let sum := mload(0x40)
                    sum := addmod(sum, mload(0x60), R)
                    mstore(0x0540, sum)
                }
                {
                    let sum := mload(0x80)
                    sum := addmod(sum, mload(0xa0), R)
                    sum := addmod(sum, mload(0xc0), R)
                    mstore(0x0560, sum)
                }
                {
                    let sum := mload(0xe0)
                    sum := addmod(sum, mload(0x0100), R)
                    mstore(0x0580, sum)
                }
                {
                    for
                        {
                            let mptr := 0x00
                            let mptr_end := 0x80
                            let sum_mptr := 0x0520
                        }
                        lt(mptr, mptr_end)
                        {
                            mptr := add(mptr, 0x20)
                            sum_mptr := add(sum_mptr, 0x20)
                        }
                    {
                        mstore(mptr, mload(sum_mptr))
                    }
                    success := batch_invert(success, 0, 0x80)
                    let r_eval := mulmod(mload(0x60), mload(0x0500), R)
                    for
                        {
                            let sum_inv_mptr := 0x40
                            let sum_inv_mptr_end := 0x80
                            let r_eval_mptr := 0x04e0
                        }
                        lt(sum_inv_mptr, sum_inv_mptr_end)
                        {
                            sum_inv_mptr := sub(sum_inv_mptr, 0x20)
                            r_eval_mptr := sub(r_eval_mptr, 0x20)
                        }
                    {
                        r_eval := mulmod(r_eval, mload(NU_MPTR), R)
                        r_eval := addmod(r_eval, mulmod(mload(sum_inv_mptr), mload(r_eval_mptr), R), R)
                    }
                    mstore(R_EVAL_MPTR, r_eval)
                }
                {
                    let nu := mload(NU_MPTR)
                    mstore(0x00, calldataload(0x0ee4))
                    mstore(0x20, calldataload(0x0f04))
                    success := ec_mul_acc(success, mload(ZETA_MPTR))
                    success := ec_add_acc(success, mload(QUOTIENT_X_MPTR), mload(QUOTIENT_Y_MPTR))
                    for
                        {
                            let mptr := 0x1080
                            let mptr_end := 0x0800
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x40) }
                    {
                        success := ec_mul_acc(success, mload(ZETA_MPTR))
                        success := ec_add_acc(success, mload(mptr), mload(add(mptr, 0x20)))
                    }
                    for
                        {
                            let mptr := 0x08a4
                            let mptr_end := 0x02e4
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x40) }
                    {
                        success := ec_mul_acc(success, mload(ZETA_MPTR))
                        success := ec_add_acc(success, calldataload(mptr), calldataload(add(mptr, 0x20)))
                    }
                    success := ec_mul_acc(success, mload(ZETA_MPTR))
                    success := ec_add_acc(success, calldataload(0x02a4), calldataload(0x02c4))
                    for
                        {
                            let mptr := 0x0224
                            let mptr_end := 0x24
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x40) }
                    {
                        success := ec_mul_acc(success, mload(ZETA_MPTR))
                        success := ec_add_acc(success, calldataload(mptr), calldataload(add(mptr, 0x20)))
                    }
                    mstore(0x80, calldataload(0x02e4))
                    mstore(0xa0, calldataload(0x0304))
                    success := ec_mul_tmp(success, mload(ZETA_MPTR))
                    success := ec_add_tmp(success, calldataload(0x0264), calldataload(0x0284))
                    success := ec_mul_tmp(success, mulmod(nu, mload(0x0440), R))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    nu := mulmod(nu, mload(NU_MPTR), R)
                    mstore(0x80, calldataload(0x08e4))
                    mstore(0xa0, calldataload(0x0904))
                    success := ec_mul_tmp(success, mulmod(nu, mload(0x0460), R))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    nu := mulmod(nu, mload(NU_MPTR), R)
                    mstore(0x80, calldataload(0x0ea4))
                    mstore(0xa0, calldataload(0x0ec4))
                    for
                        {
                            let mptr := 0x0e64
                            let mptr_end := 0x08e4
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x40) }
                    {
                        success := ec_mul_tmp(success, mload(ZETA_MPTR))
                        success := ec_add_tmp(success, calldataload(mptr), calldataload(add(mptr, 0x20)))
                    }
                    success := ec_mul_tmp(success, mulmod(nu, mload(0x0480), R))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    mstore(0x80, mload(G1_X_MPTR))
                    mstore(0xa0, mload(G1_Y_MPTR))
                    success := ec_mul_tmp(success, sub(R, mload(R_EVAL_MPTR)))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    mstore(0x80, calldataload(0x2024))
                    mstore(0xa0, calldataload(0x2044))
                    success := ec_mul_tmp(success, sub(R, mload(0x0400)))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    mstore(0x80, calldataload(0x2064))
                    mstore(0xa0, calldataload(0x2084))
                    success := ec_mul_tmp(success, mload(MU_MPTR))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    mstore(PAIRING_LHS_X_MPTR, mload(0x00))
                    mstore(PAIRING_LHS_Y_MPTR, mload(0x20))
                    mstore(PAIRING_RHS_X_MPTR, calldataload(0x2064))
                    mstore(PAIRING_RHS_Y_MPTR, calldataload(0x2084))
                }
            }

            // Random linear combine with accumulator
            if mload(HAS_ACCUMULATOR_MPTR) {
                mstore(0x00, mload(ACC_LHS_X_MPTR))
                mstore(0x20, mload(ACC_LHS_Y_MPTR))
                mstore(0x40, mload(ACC_RHS_X_MPTR))
                mstore(0x60, mload(ACC_RHS_Y_MPTR))
                mstore(0x80, mload(PAIRING_LHS_X_MPTR))
                mstore(0xa0, mload(PAIRING_LHS_Y_MPTR))
                mstore(0xc0, mload(PAIRING_RHS_X_MPTR))
                mstore(0xe0, mload(PAIRING_RHS_Y_MPTR))
                let challenge := mod(keccak256(0x00, 0x100), r)

                // [pairing_lhs] += challenge * [acc_lhs]
                success := ec_mul_acc(success, challenge)
                success := ec_add_acc(success, mload(PAIRING_LHS_X_MPTR), mload(PAIRING_LHS_Y_MPTR))
                mstore(PAIRING_LHS_X_MPTR, mload(0x00))
                mstore(PAIRING_LHS_Y_MPTR, mload(0x20))

                // [pairing_rhs] += challenge * [acc_rhs]
                mstore(0x00, mload(ACC_RHS_X_MPTR))
                mstore(0x20, mload(ACC_RHS_Y_MPTR))
                success := ec_mul_acc(success, challenge)
                success := ec_add_acc(success, mload(PAIRING_RHS_X_MPTR), mload(PAIRING_RHS_Y_MPTR))
                mstore(PAIRING_RHS_X_MPTR, mload(0x00))
                mstore(PAIRING_RHS_Y_MPTR, mload(0x20))
            }

            // Perform pairing
            success := ec_pairing(
                success,
                mload(PAIRING_LHS_X_MPTR),
                mload(PAIRING_LHS_Y_MPTR),
                mload(PAIRING_RHS_X_MPTR),
                mload(PAIRING_RHS_Y_MPTR)
            )

            // Revert if anything fails
            if iszero(success) {
                revert(0x00, 0x00)
            }

            // Return 1 as result if everything succeeds
            mstore(0x00, 1)
            return(0x00, 0x20)
        }
    }
}