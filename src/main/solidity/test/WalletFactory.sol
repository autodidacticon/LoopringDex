// SPDX-License-Identifier: GPL-2.0-or-later
// Taken from: https://github.com/Loopring/protocols/tree/master/packages/hebao_v2/contracts/base/WalletFactory.sol
// Copyright 2017 Loopring Technology Limited.
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../thirdparty/loopring-wallet/ILoopringWalletV2.sol";
import "../lib/EIP712.sol";
import "../lib/SignatureUtil.sol";
import "../thirdparty/loopring-wallet/WalletDeploymentLib.sol";


/// @title WalletFactory
/// @dev A factory contract to create a new wallet by deploying a proxy
///      in front of a real wallet.
/// @author Daniel Wang - <daniel@loopring.org>
contract WalletFactory is WalletDeploymentLib
{
    using SignatureUtil for bytes32;

    event WalletCreated (address wallet, address owner);

    bytes32             public immutable DOMAIN_SEPARATOR;

    bytes32 public constant CREATE_WALLET_TYPEHASH = keccak256(
        "createWallet(address owner,address[] guardians,uint256 quota,address inheritor,address feeRecipient,address feeToken,uint256 feeAmount,uint256 salt)");

    struct WalletConfig
    {
        address   owner;
        address[] guardians;
        uint      quota;
        address   inheritor;
        address   feeRecipient;
        address   feeToken;
        uint      feeAmount;
        bytes     signature;
    }

    constructor(
        address        _walletImplementation
        )
        WalletDeploymentLib(_walletImplementation)
    {
        DOMAIN_SEPARATOR = EIP712.hash(
            EIP712.Domain("WalletFactory", "2.0.0", address(this))
        );
    }

    /// @dev Create a new wallet by deploying a proxy.
    /// @param config The wallet's config.
    /// @param salt A salt.
    /// @return wallet The new wallet address
    function createWallet(
        WalletConfig calldata config,
        uint                  salt
        )
        external
        returns (address wallet)
    {
        _validateRequest(config, salt);
        wallet = _deploy(config.owner, salt);
        _initializeWallet(wallet, config);
    }

    /// @dev Computes the wallet address
    /// @param owner The initial wallet owner.
    /// @param salt A salt.
    /// @return wallet The wallet address
    function computeWalletAddress(
        address owner,
        uint    salt
        )
        public
        view
        returns (address)
    {
        return _computeWalletAddress(
            owner,
            salt,
            address(this)
        );
    }

    // --- Internal functions ---

    function _initializeWallet(
        address               wallet,
        WalletConfig calldata config
        )
        internal
    {
        ILoopringWalletV2(wallet).initialize(
            config.owner,
            config.guardians,
            config.quota,
            config.inheritor,
            config.feeRecipient,
            config.feeToken,
            config.feeAmount
        );

        emit WalletCreated(wallet, config.owner);
    }

    function _validateRequest(
        WalletConfig calldata config,
        uint                  salt
        )
        private
        view
    {
        require(config.owner != address(0), "INVALID_OWNER");

        bytes32 dataHash = keccak256(
            abi.encode(
                CREATE_WALLET_TYPEHASH,
                config.owner,
                keccak256(abi.encodePacked(config.guardians)),
                config.quota,
                config.inheritor,
                config.feeRecipient,
                config.feeToken,
                config.feeAmount,
                salt
            )
        );

        bytes32 signHash = EIP712.hashPacked(DOMAIN_SEPARATOR, dataHash);
        require(signHash.verifySignature(config.owner, config.signature), "INVALID_SIGNATURE");
    }
}
