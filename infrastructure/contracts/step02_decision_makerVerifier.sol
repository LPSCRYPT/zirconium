// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Halo2Verifier {
    uint256 internal constant    DELTA = 4131629893567559867359510883348571134090853742863529169391034518566172092834;
    uint256 internal constant        R = 21888242871839275222246405745257275088548364400416034343698204186575808495617; 

    uint256 internal constant FIRST_QUOTIENT_X_CPTR = 0x05e4;
    uint256 internal constant  LAST_QUOTIENT_X_CPTR = 0x06a4;

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

    uint256 internal constant CHALLENGE_MPTR = 0x0e40;

    uint256 internal constant THETA_MPTR = 0x0e40;
    uint256 internal constant  BETA_MPTR = 0x0e60;
    uint256 internal constant GAMMA_MPTR = 0x0e80;
    uint256 internal constant     Y_MPTR = 0x0ea0;
    uint256 internal constant     X_MPTR = 0x0ec0;
    uint256 internal constant  ZETA_MPTR = 0x0ee0;
    uint256 internal constant    NU_MPTR = 0x0f00;
    uint256 internal constant    MU_MPTR = 0x0f20;

    uint256 internal constant       ACC_LHS_X_MPTR = 0x0f40;
    uint256 internal constant       ACC_LHS_Y_MPTR = 0x0f60;
    uint256 internal constant       ACC_RHS_X_MPTR = 0x0f80;
    uint256 internal constant       ACC_RHS_Y_MPTR = 0x0fa0;
    uint256 internal constant             X_N_MPTR = 0x0fc0;
    uint256 internal constant X_N_MINUS_1_INV_MPTR = 0x0fe0;
    uint256 internal constant          L_LAST_MPTR = 0x1000;
    uint256 internal constant         L_BLIND_MPTR = 0x1020;
    uint256 internal constant             L_0_MPTR = 0x1040;
    uint256 internal constant   INSTANCE_EVAL_MPTR = 0x1060;
    uint256 internal constant   QUOTIENT_EVAL_MPTR = 0x1080;
    uint256 internal constant      QUOTIENT_X_MPTR = 0x10a0;
    uint256 internal constant      QUOTIENT_Y_MPTR = 0x10c0;
    uint256 internal constant          R_EVAL_MPTR = 0x10e0;
    uint256 internal constant   PAIRING_LHS_X_MPTR = 0x1100;
    uint256 internal constant   PAIRING_LHS_Y_MPTR = 0x1120;
    uint256 internal constant   PAIRING_RHS_X_MPTR = 0x1140;
    uint256 internal constant   PAIRING_RHS_Y_MPTR = 0x1160;

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
                mstore(0x05a0, 0x0ea738cac13d677cdf3475dbda550e69fbecaf5f28d2b6a49065890180458270) // vk_digest
                mstore(0x05c0, 0x0000000000000000000000000000000000000000000000000000000000000008) // num_instances

                // Check valid length of proof
                success := and(success, eq(0x0e40, proof.length))

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
                    { let proof_cptr_end := add(proof_cptr, 0x0180) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)

                // Phase 2
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0180) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)
                challenge_mptr := squeeze_challenge_cont(challenge_mptr, r)

                // Phase 3
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0280) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)

                // Phase 4
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0100) }
                    lt(proof_cptr, proof_cptr_end)
                    {}
                {
                    success, proof_cptr, hash_mptr := read_ec_point(success, proof_cptr, hash_mptr, q)
                }

                challenge_mptr, hash_mptr := squeeze_challenge(challenge_mptr, hash_mptr, r)

                // Read evaluations
                for
                    { let proof_cptr_end := add(proof_cptr, 0x0740) }
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
                mstore(0x05a0, 0x0ea738cac13d677cdf3475dbda550e69fbecaf5f28d2b6a49065890180458270) // vk_digest
                mstore(0x05c0, 0x0000000000000000000000000000000000000000000000000000000000000008) // num_instances
                mstore(0x05e0, 0x0000000000000000000000000000000000000000000000000000000000000011) // k
                mstore(0x0600, 0x30643640b9f82f90e83b698e5ea6179c7c05542e859533b48b9953a2f5360801) // n_inv
                mstore(0x0620, 0x304cd1e79cfa5b0f054e981a27ed7706e7ea6b06a7f266ef8db819c179c2c3ea) // omega
                mstore(0x0640, 0x193586da872cdeff023d6ab2263a131b4780db8878be3c3b7f8f019c06fcb0fb) // omega_inv
                mstore(0x0660, 0x299110e6835fd73731fb3ce6de87151988da403c265467a96b9cda0d7daa72e4) // omega_inv_to_l
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
                mstore(0x0840, 0x068c146999c078d3aa268c65414e947036adc5e5aa982e4352ea0d938217ed6d) // fixed_comms[0].x
                mstore(0x0860, 0x25140c7b0f8e42929eccebd4526faab48df87a71b3407656f3d6a56594d4974f) // fixed_comms[0].y
                mstore(0x0880, 0x0b457f7323baa1c0008fd1859e9e520bf8668739d39281fd9be15d520c34be65) // fixed_comms[1].x
                mstore(0x08a0, 0x0398835149cae92836249b773be89a3628429b5d18ed2de5c3ab8fd69b3e1578) // fixed_comms[1].y
                mstore(0x08c0, 0x19146ca81ce8a406bb4735560ba2329b9ec39f33661e05ec79eec5c12e12b6a6) // fixed_comms[2].x
                mstore(0x08e0, 0x142ec23933dc682097bb1aede5a3de08b397c8e036c46168063ea094fcb18792) // fixed_comms[2].y
                mstore(0x0900, 0x18beb969dccc1ae964cf7f9d994681399ce3fd93e9e8f788da43307b628da3dc) // fixed_comms[3].x
                mstore(0x0920, 0x2087b712d2fdcd9c8db075d6d640fcb4c17b91900d0f883ecf01792473221cdc) // fixed_comms[3].y
                mstore(0x0940, 0x24088d69ddadddfb205393632f8cf1fe11bdf533332d9dda8b91c082b19d8150) // fixed_comms[4].x
                mstore(0x0960, 0x1f1e11bf7dff7c9127e5d98e66fd076de7b21e781a6017d6d5202ed39501d6f9) // fixed_comms[4].y
                mstore(0x0980, 0x17375d86027b8b39159a37fabcc902e0170de3c2eb9945418c4ee3748813b280) // fixed_comms[5].x
                mstore(0x09a0, 0x046f9f32bf5c7561cc5312c0eb918148173d87d04eb755ea29ef3732fa6fd4f6) // fixed_comms[5].y
                mstore(0x09c0, 0x2c66f741532734766c913b0313d0ada60d1a2c4979a0d35995f908bf2a8d5cc4) // fixed_comms[6].x
                mstore(0x09e0, 0x2ea03fb9f9395d6efa53a8d65fbed0ffa65f825fbcc6fe6a23a4dd5e5a3550cb) // fixed_comms[6].y
                mstore(0x0a00, 0x27f15d8acb1643560397476b67bb513c6db2b0b49922ffbe351de60596d52e62) // fixed_comms[7].x
                mstore(0x0a20, 0x178d4851663197e7e173969dbb474a132d30731279db2f3384135d507d4740f4) // fixed_comms[7].y
                mstore(0x0a40, 0x0445a357df67769752fde32efd6dda39e45235064a229fd797cebde5d55d27f3) // fixed_comms[8].x
                mstore(0x0a60, 0x3037be6f9c469815b2ae3e5b3e31848864c7998ae50f3fd42ad9fd122f506aad) // fixed_comms[8].y
                mstore(0x0a80, 0x0bc6049ed5ccc3f54356916404742c20adcbfdb81a55186f2fc5b32d857d528d) // fixed_comms[9].x
                mstore(0x0aa0, 0x14738ba07eb17dcbf9cb4c33cc650a9aff752772f4b2a9463f045d4a99b753ba) // fixed_comms[9].y
                mstore(0x0ac0, 0x0bc6049ed5ccc3f54356916404742c20adcbfdb81a55186f2fc5b32d857d528d) // fixed_comms[10].x
                mstore(0x0ae0, 0x14738ba07eb17dcbf9cb4c33cc650a9aff752772f4b2a9463f045d4a99b753ba) // fixed_comms[10].y
                mstore(0x0b00, 0x18f718fa63dcdff3b31d1d689551afc7d165686ab4d095238f03d5e20e832bcd) // fixed_comms[11].x
                mstore(0x0b20, 0x15867405a5080adad4f6fab8c65c489e5dbf7ff07eca8c2a5a911a00145378df) // fixed_comms[11].y
                mstore(0x0b40, 0x126df2892f1c692a1978aa2f9f4646534b46c5d5ae932192cb6fd8d0281cf356) // fixed_comms[12].x
                mstore(0x0b60, 0x0ed4a7f10cc802405ca71aeb2656f56dc5868c54f80052294010be59a358e441) // fixed_comms[12].y
                mstore(0x0b80, 0x2b4fd7e3e4dea2cc9ccedbb806abc57563f5e67f481a7f212b58ed90dc29064c) // fixed_comms[13].x
                mstore(0x0ba0, 0x02f6ef9860c9a30f04b77d9fe6d68a4a1bcfa2528641e03c53ab329bea565561) // fixed_comms[13].y
                mstore(0x0bc0, 0x0000000000000000000000000000000000000000000000000000000000000000) // fixed_comms[14].x
                mstore(0x0be0, 0x0000000000000000000000000000000000000000000000000000000000000000) // fixed_comms[14].y
                mstore(0x0c00, 0x0000000000000000000000000000000000000000000000000000000000000000) // fixed_comms[15].x
                mstore(0x0c20, 0x0000000000000000000000000000000000000000000000000000000000000000) // fixed_comms[15].y
                mstore(0x0c40, 0x12ea9be0cf5bd1d6944d65e37d768f538ff7e980be2391381e7ace0e7daf6e74) // permutation_comms[0].x
                mstore(0x0c60, 0x153ba797f313c97c6bddbf00112b19c415cfb3bef1fe473ef2d3c615f0201b45) // permutation_comms[0].y
                mstore(0x0c80, 0x282342d6939e637f7786ce206712dc19fb8e3b94bdeb6fcc77c16903fea7c1d9) // permutation_comms[1].x
                mstore(0x0ca0, 0x00f25d8bf29a37408ecb18c8a00e246c486e4395a165cc6a4dde4561d4243c1d) // permutation_comms[1].y
                mstore(0x0cc0, 0x0dacc40ccbc7cb32fbe9758d5a9186725d3c00c5ce1a56ac690fb5d55bb158e2) // permutation_comms[2].x
                mstore(0x0ce0, 0x24d249efeb6348d24dc24dc876109c45b1606cd8896e94bdd31ecd34394a2c34) // permutation_comms[2].y
                mstore(0x0d00, 0x06335ad8bb73721e7bd3610d33ef0992e8417df90bfe77b2240f055f1416009a) // permutation_comms[3].x
                mstore(0x0d20, 0x25ad7de0c114973b8c397b9cf265801461e01a05627f915585f100b349ed6596) // permutation_comms[3].y
                mstore(0x0d40, 0x023978ae4f705c91efdd841bcd8c01066516dcfb766c1924659a14051d1208bf) // permutation_comms[4].x
                mstore(0x0d60, 0x207a2d6c1397cad19ea62f327d769e47fdcfe053dd416e2b0792cbc98e716092) // permutation_comms[4].y
                mstore(0x0d80, 0x039c6be386b5f6e51679283c77a4588aabb51f93cf6d8c9a2fbbdcd74dbf1a67) // permutation_comms[5].x
                mstore(0x0da0, 0x0e93b7366cda4494b93b5b97d1a8b0355a53f11e9132dc10e9fd46356a4da8d6) // permutation_comms[5].y
                mstore(0x0dc0, 0x2c4cd6b992852a696b9cb00e9849efe96b173d6e6ca564e6716e8bd79d93480a) // permutation_comms[6].x
                mstore(0x0de0, 0x1eff07cb5e56abf6cbbdd77bf98a3c65ba6e42a397187f2840ad810351991bb4) // permutation_comms[6].y
                mstore(0x0e00, 0x0ceebb9066ad25534ede3fef4c0d9c0cd3b25c77004ef7c1605eefb16391745a) // permutation_comms[7].x
                mstore(0x0e20, 0x05907762f52d1f6c712353ade81e2b469c18d0bdeb5730c235ec6332e3a8ace9) // permutation_comms[7].y

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
                    let f_11 := calldataload(0x0924)
                    let var0 := 0x2
                    let var1 := sub(R, f_11)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_11, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_4 := calldataload(0x0764)
                    let a_0 := calldataload(0x06e4)
                    let a_2 := calldataload(0x0724)
                    let var7 := addmod(a_0, a_2, R)
                    let var8 := sub(R, var7)
                    let var9 := addmod(a_4, var8, R)
                    let var10 := mulmod(var6, var9, R)
                    quotient_eval_numer := var10
                }
                {
                    let f_12 := calldataload(0x0944)
                    let var0 := 0x2
                    let var1 := sub(R, f_12)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_12, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_5 := calldataload(0x0784)
                    let a_1 := calldataload(0x0704)
                    let a_3 := calldataload(0x0744)
                    let var7 := addmod(a_1, a_3, R)
                    let var8 := sub(R, var7)
                    let var9 := addmod(a_5, var8, R)
                    let var10 := mulmod(var6, var9, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var10, r)
                }
                {
                    let f_11 := calldataload(0x0924)
                    let var0 := 0x1
                    let var1 := sub(R, f_11)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_11, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_4 := calldataload(0x0764)
                    let a_0 := calldataload(0x06e4)
                    let a_2 := calldataload(0x0724)
                    let var7 := mulmod(a_0, a_2, R)
                    let var8 := sub(R, var7)
                    let var9 := addmod(a_4, var8, R)
                    let var10 := mulmod(var6, var9, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var10, r)
                }
                {
                    let f_12 := calldataload(0x0944)
                    let var0 := 0x1
                    let var1 := sub(R, f_12)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_12, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_5 := calldataload(0x0784)
                    let a_1 := calldataload(0x0704)
                    let a_3 := calldataload(0x0744)
                    let var7 := mulmod(a_1, a_3, R)
                    let var8 := sub(R, var7)
                    let var9 := addmod(a_5, var8, R)
                    let var10 := mulmod(var6, var9, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var10, r)
                }
                {
                    let f_11 := calldataload(0x0924)
                    let var0 := 0x1
                    let var1 := sub(R, f_11)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_11, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_4 := calldataload(0x0764)
                    let a_0 := calldataload(0x06e4)
                    let a_2 := calldataload(0x0724)
                    let var7 := sub(R, a_2)
                    let var8 := addmod(a_0, var7, R)
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_4, var9, R)
                    let var11 := mulmod(var6, var10, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var11, r)
                }
                {
                    let f_12 := calldataload(0x0944)
                    let var0 := 0x1
                    let var1 := sub(R, f_12)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_12, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_5 := calldataload(0x0784)
                    let a_1 := calldataload(0x0704)
                    let a_3 := calldataload(0x0744)
                    let var7 := sub(R, a_3)
                    let var8 := addmod(a_1, var7, R)
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_5, var9, R)
                    let var11 := mulmod(var6, var10, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var11, r)
                }
                {
                    let f_13 := calldataload(0x0964)
                    let var0 := 0x1
                    let var1 := sub(R, f_13)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_13, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_4 := calldataload(0x0764)
                    let a_4_prev_1 := calldataload(0x07a4)
                    let var7 := 0x0
                    let a_0 := calldataload(0x06e4)
                    let a_2 := calldataload(0x0724)
                    let var8 := mulmod(a_0, a_2, R)
                    let var9 := addmod(var7, var8, R)
                    let a_1 := calldataload(0x0704)
                    let a_3 := calldataload(0x0744)
                    let var10 := mulmod(a_1, a_3, R)
                    let var11 := addmod(var9, var10, R)
                    let var12 := addmod(a_4_prev_1, var11, R)
                    let var13 := sub(R, var12)
                    let var14 := addmod(a_4, var13, R)
                    let var15 := mulmod(var6, var14, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var15, r)
                }
                {
                    let f_13 := calldataload(0x0964)
                    let var0 := 0x2
                    let var1 := sub(R, f_13)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_13, var2, R)
                    let var4 := 0x3
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_4 := calldataload(0x0764)
                    let var7 := 0x0
                    let a_0 := calldataload(0x06e4)
                    let a_2 := calldataload(0x0724)
                    let var8 := mulmod(a_0, a_2, R)
                    let var9 := addmod(var7, var8, R)
                    let a_1 := calldataload(0x0704)
                    let a_3 := calldataload(0x0744)
                    let var10 := mulmod(a_1, a_3, R)
                    let var11 := addmod(var9, var10, R)
                    let var12 := sub(R, var11)
                    let var13 := addmod(a_4, var12, R)
                    let var14 := mulmod(var6, var13, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var14, r)
                }
                {
                    let f_13 := calldataload(0x0964)
                    let var0 := 0x1
                    let var1 := sub(R, f_13)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_13, var2, R)
                    let var4 := 0x2
                    let var5 := addmod(var4, var1, R)
                    let var6 := mulmod(var3, var5, R)
                    let a_4 := calldataload(0x0764)
                    let a_2 := calldataload(0x0724)
                    let var7 := mulmod(var0, a_2, R)
                    let a_3 := calldataload(0x0744)
                    let var8 := mulmod(var7, a_3, R)
                    let var9 := sub(R, var8)
                    let var10 := addmod(a_4, var9, R)
                    let var11 := mulmod(var6, var10, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var11, r)
                }
                {
                    let f_14 := calldataload(0x0984)
                    let var0 := 0x2
                    let var1 := sub(R, f_14)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_14, var2, R)
                    let a_4 := calldataload(0x0764)
                    let a_4_prev_1 := calldataload(0x07a4)
                    let var4 := 0x1
                    let a_2 := calldataload(0x0724)
                    let var5 := mulmod(var4, a_2, R)
                    let a_3 := calldataload(0x0744)
                    let var6 := mulmod(var5, a_3, R)
                    let var7 := mulmod(a_4_prev_1, var6, R)
                    let var8 := sub(R, var7)
                    let var9 := addmod(a_4, var8, R)
                    let var10 := mulmod(var3, var9, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var10, r)
                }
                {
                    let f_15 := calldataload(0x09a4)
                    let a_4 := calldataload(0x0764)
                    let var0 := 0x0
                    let a_2 := calldataload(0x0724)
                    let var1 := addmod(var0, a_2, R)
                    let a_3 := calldataload(0x0744)
                    let var2 := addmod(var1, a_3, R)
                    let var3 := sub(R, var2)
                    let var4 := addmod(a_4, var3, R)
                    let var5 := mulmod(f_15, var4, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var5, r)
                }
                {
                    let f_14 := calldataload(0x0984)
                    let var0 := 0x1
                    let var1 := sub(R, f_14)
                    let var2 := addmod(var0, var1, R)
                    let var3 := mulmod(f_14, var2, R)
                    let a_4 := calldataload(0x0764)
                    let a_4_prev_1 := calldataload(0x07a4)
                    let var4 := 0x0
                    let a_2 := calldataload(0x0724)
                    let var5 := addmod(var4, a_2, R)
                    let a_3 := calldataload(0x0744)
                    let var6 := addmod(var5, a_3, R)
                    let var7 := addmod(a_4_prev_1, var6, R)
                    let var8 := sub(R, var7)
                    let var9 := addmod(a_4, var8, R)
                    let var10 := mulmod(var3, var9, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var10, r)
                }
                {
                    let f_5 := calldataload(0x0864)
                    let var0 := 0x0
                    let var1 := mulmod(f_5, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_6 := calldataload(0x0884)
                    let var0 := 0x0
                    let var1 := mulmod(f_6, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_7 := calldataload(0x08a4)
                    let var0 := 0x0
                    let var1 := mulmod(f_7, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_8 := calldataload(0x08c4)
                    let var0 := 0x0
                    let var1 := mulmod(f_8, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_9 := calldataload(0x08e4)
                    let var0 := 0x0
                    let var1 := mulmod(f_9, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let f_10 := calldataload(0x0904)
                    let var0 := 0x0
                    let var1 := mulmod(f_10, var0, R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), var1, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := addmod(l_0, sub(R, mulmod(l_0, calldataload(0x0ae4), R)), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let perm_z_last := calldataload(0x0ba4)
                    let eval := mulmod(mload(L_LAST_MPTR), addmod(mulmod(perm_z_last, perm_z_last, R), sub(R, perm_z_last), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let eval := mulmod(mload(L_0_MPTR), addmod(calldataload(0x0b44), sub(R, calldataload(0x0b24)), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let eval := mulmod(mload(L_0_MPTR), addmod(calldataload(0x0ba4), sub(R, calldataload(0x0b84)), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let gamma := mload(GAMMA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let lhs := calldataload(0x0b04)
                    let rhs := calldataload(0x0ae4)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x06e4), mulmod(beta, calldataload(0x09e4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x0704), mulmod(beta, calldataload(0x0a04), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x0724), mulmod(beta, calldataload(0x0a24), R), R), gamma, R), R)
                    mstore(0x00, mulmod(beta, mload(X_MPTR), R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x06e4), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x0704), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x0724), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    let left_sub_right := addmod(lhs, sub(R, rhs), R)
                    let eval := addmod(left_sub_right, sub(R, mulmod(left_sub_right, addmod(mload(L_LAST_MPTR), mload(L_BLIND_MPTR), R), R)), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let gamma := mload(GAMMA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let lhs := calldataload(0x0b64)
                    let rhs := calldataload(0x0b44)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x0744), mulmod(beta, calldataload(0x0a44), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x0764), mulmod(beta, calldataload(0x0a64), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x0784), mulmod(beta, calldataload(0x0a84), R), R), gamma, R), R)
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x0744), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x0764), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x0784), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    let left_sub_right := addmod(lhs, sub(R, rhs), R)
                    let eval := addmod(left_sub_right, sub(R, mulmod(left_sub_right, addmod(mload(L_LAST_MPTR), mload(L_BLIND_MPTR), R), R)), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let gamma := mload(GAMMA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let lhs := calldataload(0x0bc4)
                    let rhs := calldataload(0x0ba4)
                    lhs := mulmod(lhs, addmod(addmod(calldataload(0x07c4), mulmod(beta, calldataload(0x0aa4), R), R), gamma, R), R)
                    lhs := mulmod(lhs, addmod(addmod(mload(INSTANCE_EVAL_MPTR), mulmod(beta, calldataload(0x0ac4), R), R), gamma, R), R)
                    rhs := mulmod(rhs, addmod(addmod(calldataload(0x07c4), mload(0x00), R), gamma, R), R)
                    mstore(0x00, mulmod(mload(0x00), DELTA, R))
                    rhs := mulmod(rhs, addmod(addmod(mload(INSTANCE_EVAL_MPTR), mload(0x00), R), gamma, R), R)
                    let left_sub_right := addmod(lhs, sub(R, rhs), R)
                    let eval := addmod(left_sub_right, sub(R, mulmod(left_sub_right, addmod(mload(L_LAST_MPTR), mload(L_BLIND_MPTR), R), R)), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x0be4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x0be4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_1 := calldataload(0x07e4)
                        let f_2 := calldataload(0x0804)
                        table := f_1
                        table := addmod(mulmod(table, theta, R), f_2, R)
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_5 := calldataload(0x0864)
                        let var0 := 0x1
                        let var1 := mulmod(f_5, var0, R)
                        let a_0 := calldataload(0x06e4)
                        let var2 := mulmod(var1, a_0, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efff8001
                        let var6 := mulmod(var4, var5, R)
                        let var7 := addmod(var2, var6, R)
                        let a_4 := calldataload(0x0764)
                        let var8 := mulmod(var1, a_4, R)
                        let var9 := 0x0
                        let var10 := mulmod(var4, var9, R)
                        let var11 := addmod(var8, var10, R)
                        input_0 := var7
                        input_0 := addmod(mulmod(input_0, theta, R), var11, R)
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x0c24), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x0c04), sub(R, calldataload(0x0be4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x0c44), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x0c44), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_1 := calldataload(0x07e4)
                        let f_2 := calldataload(0x0804)
                        table := f_1
                        table := addmod(mulmod(table, theta, R), f_2, R)
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_6 := calldataload(0x0884)
                        let var0 := 0x1
                        let var1 := mulmod(f_6, var0, R)
                        let a_1 := calldataload(0x0704)
                        let var2 := mulmod(var1, a_1, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efff8001
                        let var6 := mulmod(var4, var5, R)
                        let var7 := addmod(var2, var6, R)
                        let a_5 := calldataload(0x0784)
                        let var8 := mulmod(var1, a_5, R)
                        let var9 := 0x0
                        let var10 := mulmod(var4, var9, R)
                        let var11 := addmod(var8, var10, R)
                        input_0 := var7
                        input_0 := addmod(mulmod(input_0, theta, R), var11, R)
                        input_0 := addmod(input_0, beta, R)
                    }
                    let lhs
                    let rhs
                    rhs := table
                    {
                        let tmp := input_0
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x0c84), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x0c64), sub(R, calldataload(0x0c44)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x0ca4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x0ca4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_3 := calldataload(0x0824)
                        table := f_3
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_7 := calldataload(0x08a4)
                        let var0 := 0x1
                        let var1 := mulmod(f_7, var0, R)
                        let a_0 := calldataload(0x06e4)
                        let var2 := mulmod(var1, a_0, R)
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
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x0ce4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x0cc4), sub(R, calldataload(0x0ca4)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x0d04), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x0d04), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_3 := calldataload(0x0824)
                        table := f_3
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_8 := calldataload(0x08c4)
                        let var0 := 0x1
                        let var1 := mulmod(f_8, var0, R)
                        let a_1 := calldataload(0x0704)
                        let var2 := mulmod(var1, a_1, R)
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
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x0d44), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x0d24), sub(R, calldataload(0x0d04)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x0d64), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x0d64), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_4 := calldataload(0x0844)
                        table := f_4
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_9 := calldataload(0x08e4)
                        let var0 := 0x1
                        let var1 := mulmod(f_9, var0, R)
                        let a_0 := calldataload(0x06e4)
                        let var2 := mulmod(var1, a_0, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x0
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
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x0da4), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x0d84), sub(R, calldataload(0x0d64)), R), R)
                    }
                    let eval := mulmod(addmod(1, sub(R, addmod(mload(L_BLIND_MPTR), mload(L_LAST_MPTR), R)), R), addmod(lhs, sub(R, rhs), R), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_0 := mload(L_0_MPTR)
                    let eval := mulmod(l_0, calldataload(0x0dc4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let l_last := mload(L_LAST_MPTR)
                    let eval := mulmod(l_last, calldataload(0x0dc4), R)
                    quotient_eval_numer := addmod(mulmod(quotient_eval_numer, y, r), eval, r)
                }
                {
                    let theta := mload(THETA_MPTR)
                    let beta := mload(BETA_MPTR)
                    let table
                    {
                        let f_4 := calldataload(0x0844)
                        table := f_4
                        table := addmod(table, beta, R)
                    }
                    let input_0
                    {
                        let f_10 := calldataload(0x0904)
                        let var0 := 0x1
                        let var1 := mulmod(f_10, var0, R)
                        let a_1 := calldataload(0x0704)
                        let var2 := mulmod(var1, a_1, R)
                        let var3 := sub(R, var1)
                        let var4 := addmod(var0, var3, R)
                        let var5 := 0x0
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
                        rhs := addmod(rhs, sub(R, mulmod(calldataload(0x0e04), tmp, R)), R)
                        lhs := mulmod(mulmod(table, tmp, R), addmod(calldataload(0x0de4), sub(R, calldataload(0x0dc4)), R), R)
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
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x09c4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, mload(QUOTIENT_EVAL_MPTR), R), R)
                    for
                        {
                            let mptr := 0x0ac4
                            let mptr_end := 0x09c4
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x20) }
                    {
                        r_eval := addmod(mulmod(r_eval, zeta, R), mulmod(coeff, calldataload(mptr), R), R)
                    }
                    for
                        {
                            let mptr := 0x09a4
                            let mptr_end := 0x07a4
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x20) }
                    {
                        r_eval := addmod(mulmod(r_eval, zeta, R), mulmod(coeff, calldataload(mptr), R), R)
                    }
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x0e04), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x0da4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x0d44), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x0ce4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x0c84), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x0c24), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(coeff, calldataload(0x0784), R), R)
                    for
                        {
                            let mptr := 0x0744
                            let mptr_end := 0x06c4
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
                    r_eval := addmod(r_eval, mulmod(mload(0x40), calldataload(0x07a4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x60), calldataload(0x0764), R), R)
                    r_eval := mulmod(r_eval, mload(0x0440), R)
                    mstore(0x04c0, r_eval)
                }
                {
                    let zeta := mload(ZETA_MPTR)
                    let r_eval := 0
                    r_eval := addmod(r_eval, mulmod(mload(0x80), calldataload(0x0b84), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0xa0), calldataload(0x0b44), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0xc0), calldataload(0x0b64), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0x80), calldataload(0x0b24), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0xa0), calldataload(0x0ae4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0xc0), calldataload(0x0b04), R), R)
                    r_eval := mulmod(r_eval, mload(0x0460), R)
                    mstore(0x04e0, r_eval)
                }
                {
                    let zeta := mload(ZETA_MPTR)
                    let r_eval := 0
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x0dc4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x0de4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x0d64), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x0d84), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x0d04), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x0d24), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x0ca4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x0cc4), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x0c44), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x0c64), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x0be4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x0c04), R), R)
                    r_eval := mulmod(r_eval, zeta, R)
                    r_eval := addmod(r_eval, mulmod(mload(0xe0), calldataload(0x0ba4), R), R)
                    r_eval := addmod(r_eval, mulmod(mload(0x0100), calldataload(0x0bc4), R), R)
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
                    mstore(0x00, calldataload(0x05a4))
                    mstore(0x20, calldataload(0x05c4))
                    success := ec_mul_acc(success, mload(ZETA_MPTR))
                    success := ec_add_acc(success, mload(QUOTIENT_X_MPTR), mload(QUOTIENT_Y_MPTR))
                    for
                        {
                            let mptr := 0x0e00
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
                            let mptr := 0x0324
                            let mptr_end := 0x0164
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x40) }
                    {
                        success := ec_mul_acc(success, mload(ZETA_MPTR))
                        success := ec_add_acc(success, calldataload(mptr), calldataload(add(mptr, 0x20)))
                    }
                    for
                        {
                            let mptr := 0x0124
                            let mptr_end := 0x24
                        }
                        lt(mptr_end, mptr)
                        { mptr := sub(mptr, 0x40) }
                    {
                        success := ec_mul_acc(success, mload(ZETA_MPTR))
                        success := ec_add_acc(success, calldataload(mptr), calldataload(add(mptr, 0x20)))
                    }
                    mstore(0x80, calldataload(0x0164))
                    mstore(0xa0, calldataload(0x0184))
                    success := ec_mul_tmp(success, mulmod(nu, mload(0x0440), R))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    nu := mulmod(nu, mload(NU_MPTR), R)
                    mstore(0x80, calldataload(0x03a4))
                    mstore(0xa0, calldataload(0x03c4))
                    success := ec_mul_tmp(success, mload(ZETA_MPTR))
                    success := ec_add_tmp(success, calldataload(0x0364), calldataload(0x0384))
                    success := ec_mul_tmp(success, mulmod(nu, mload(0x0460), R))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    nu := mulmod(nu, mload(NU_MPTR), R)
                    mstore(0x80, calldataload(0x0564))
                    mstore(0xa0, calldataload(0x0584))
                    for
                        {
                            let mptr := 0x0524
                            let mptr_end := 0x03a4
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
                    mstore(0x80, calldataload(0x0e24))
                    mstore(0xa0, calldataload(0x0e44))
                    success := ec_mul_tmp(success, sub(R, mload(0x0400)))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    mstore(0x80, calldataload(0x0e64))
                    mstore(0xa0, calldataload(0x0e84))
                    success := ec_mul_tmp(success, mload(MU_MPTR))
                    success := ec_add_acc(success, mload(0x80), mload(0xa0))
                    mstore(PAIRING_LHS_X_MPTR, mload(0x00))
                    mstore(PAIRING_LHS_Y_MPTR, mload(0x20))
                    mstore(PAIRING_RHS_X_MPTR, calldataload(0x0e64))
                    mstore(PAIRING_RHS_Y_MPTR, calldataload(0x0e84))
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