// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

interface IHypernova {
    event HNBridgePauseState(
        address indexed owner,
        bool paused
    );
    event MessagePosted(
        address indexed caller,
        uint256 indexed messageId,
        uint64 indexed toChainId,
        bytes messageData
    );
    
    event UpdatedAdmin(address indexed owner,address admin);
    event UpdatedHNConfig(address indexed admin, HNConfig);

    struct HNConfig {
        bool enabled;
        uint64 cm;
        uint64 vm;
        // GasCost in Quants = gas_used * gas_unit_price => u64 * u64 => uint128 is enough. But In percentage calculaiton it might get oeverflowed. So, using u256
        uint256 cg;
        // cr is rewarded in supra, supra balance transactions done in u64. (Max supra supply 100 billion)
        uint64 cr;
        // x is the traffic in a day to hypernova u64 seems fine
        uint64 x;
        // V charged in supra, supra balance transactions done in u64. (Max supra supply 100 billion)
        uint64 v;
    }
    
    function initialize(address _admin, uint256 _msgId) external;
    function changeState(bool _isPaused) external;
    function setAdmin(address _admin) external;
    function postMessage(bytes memory messageData, uint64 toChainId) external;
    function addOrUpdateHNConfig(
        bool enabled,
        uint64 toChaiID,
        uint256 cg,
        uint64 cm,
        uint64 vm,
        uint64 x
    ) external ;
    function getHNConfig(uint64 toChainId) external view returns (HNConfig memory);
    function getImplementationAddress() external view returns (address);
    function upgradeImplementation(address newImplementation) external returns (address);
    function getNextMsgId() external view returns (uint256);
    function computeVerificationFee(uint64 cr, uint64 x, uint64 vm) external pure returns (uint64);
    function computeCUreward(uint256 cg, uint64 cm) external pure returns (uint64);
    function PERCENTAGE_BASE() external view returns (uint64);
    function checkIsHypernovaPaused() external view returns(bool);
    function admin() external view returns(address);
}
