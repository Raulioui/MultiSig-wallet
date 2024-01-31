// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MultiSignWallet} from "../src/MultiSignWallet.sol";

contract MultiSignTest is Test {
    MultiSignWallet wallet;

    uint constant public MAX_OWNER_COUNT = 5;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }


    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = address(1);
        owners[1] = address(2);
        owners[2] = address(3);

        wallet = new MultiSignWallet(owners, 2);
    }

    function testRevertIfArrayLenghtOverpasses() public {
        address[] memory owners = new address[](MAX_OWNER_COUNT + 1);

        vm.expectRevert("Invalid number of owners");
        MultiSignWallet _wallet = new MultiSignWallet(owners, 2);
    }
    
    function testRevertIfConfirmationsNumberIsZero() public {
        vm.expectRevert("Invalid number of confirmations");
        MultiSignWallet _wallet = new MultiSignWallet(new address[](3), 0);
    }

    function testRevertIfConfirmationsNumberHigh() public {
        address[] memory owners = new address[](3);
        owners[0] = address(5);
        owners[1] = address(6);
        owners[2] = address(7);
        vm.expectRevert("Invalid number of confirmations");
        MultiSignWallet _wallet = new MultiSignWallet(owners, 5);
    }

    function testRevertIfAddressIsInvalid() public {
        address[] memory owners = new address[](3);
        owners[0] = address(0);
        vm.expectRevert("Invalid address provided");
        MultiSignWallet _wallet = new MultiSignWallet(owners, 2);
    }

    function testRevertIfAddressIsDuplicated() public  {
        address[] memory owners = new address[](3);
        owners[0] = address(1);
        owners[1] = address(1);
        owners[2] = address(3);

        vm.expectRevert("Duplicate owner");
        MultiSignWallet _wallet = new MultiSignWallet(owners, 2);
    }

    function testInitializeWallet() public {
        address[] memory owners = new address[](3);
        owners[0] = address(1);
        owners[1] = address(2);
        owners[2] = address(3);

        MultiSignWallet _wallet = new MultiSignWallet(owners, 2);

        assertEq(_wallet.owners(0), address(1));
        assertEq(_wallet.owners(1), address(2));
        assertEq(_wallet.owners(2), address(3));

        assertEq(_wallet.isOwner(address(1)), true);
        assertEq(_wallet.isOwner(address(2)), true);
        assertEq(_wallet.isOwner(address(3)), true);
        assertEq(_wallet.confirmationsRequired(), 2);
    }

    function testRevertsSubmitIfReceiverIsZero() public {
        vm.startPrank(address(1));
        vm.expectRevert("Invalid address provided");
        wallet.submitTransaction{value: 0}(address(0), "");
    }

    function testRevertsSubmitIfValueIs0() public {
        vm.startPrank(address(1));
        vm.deal(address(1), 1 ether);
        vm.expectRevert("Invalid amount provided");
        wallet.submitTransaction{value: 0}(address(10), "");
    }

    function testSubmitTransaction() public {
        vm.startPrank(address(1));
        vm.deal(address(1), 1 ether);
        wallet.submitTransaction{value: 1000}(address(10), "");

        (address to, uint value, bytes memory data, bool executed) = wallet.transactions(0);

        assertEq(to, address(10));
        assertEq(value, 1000);
        assertEq(data, "");
        assertEq(executed, false);
    }

    function testConfirmTransition() public {
        vm.startPrank(address(1));
        vm.deal(address(1), 1 ether);
        wallet.submitTransaction{value: 1000}(address(10), "");

        vm.startPrank(address(2));
        wallet.confirmTransaction(0);

        assertEq(wallet.isApproved(0, address(2)), true);
    }

    function testExecuteTransaction() public {
        vm.startPrank(address(1));
        vm.deal(address(1), 1 ether);
        wallet.submitTransaction{value: 1000}(address(10), "");

        vm.startPrank(address(2));
        wallet.confirmTransaction(0);

        vm.startPrank(address(3));
        wallet.confirmTransaction(0);

        (,,, bool executed) = wallet.transactions(0);

        assertEq(executed, true);
    }

}
