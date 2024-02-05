// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Supplychain} from "../src/Supplychain.sol";

contract SupplyChainTest is Test {
    ///////////////
    //// SETUP ////
    ///////////////

    Supplychain public supplyChain;

    function setUp() public {
        supplyChain = new Supplychain();
    }

    receive() external payable {}

    fallback() external payable {}

    ///////////////
    //// ERROR ////
    ///////////////
    error ShipmentNotExist();
    error NotShipmentSender();
    error NotShipmentRecipient();
    error NotShipmentRecipientOrSender();
    error NotOrderedStatus();
    error NotShippedStatus();
    error NotDeliveredStatus();
    error ShipmentHasComplete();
    error ShipmentHasBeenCancelled();

    ///////////////////////
    //// FUNCTION TEST ////
    ///////////////////////
    function test_CreateShipment() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        (
            uint _id,
            uint _price,
            uint _complateTime,
            string memory _name,
            address _sender,
            address _recipient,

        ) = supplyChain.shipments(1);

        assertEq(_id, 1);
        assertEq(_price, price * (10 ** 18));
        assertEq(_complateTime, 0);
        assertEq(_name, name);
        assertEq(_sender, address(this));
        assertEq(_recipient, recipient);
    }

    function test_ChangeShipment() public {
        // Setup
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        (
            ,
            uint _oldPrice,
            ,
            string memory _oldName,
            ,
            address _oldRecipient,

        ) = supplyChain.shipments(1);

        assertEq(_oldPrice, price * (10 ** 18));
        assertEq(_oldName, name);
        assertEq(_oldRecipient, recipient);

        // Change Shipment
        uint256 shipmentId = 1;
        uint256 newPrice = 5;
        string memory newName = "House";
        address newRecipient = address(0x246);

        supplyChain.changeShipment(shipmentId, newPrice, newName, newRecipient);

        (
            ,
            uint _newPrice,
            ,
            string memory _newName,
            ,
            address _newRecipient,

        ) = supplyChain.shipments(1);

        assertEq(_newPrice, newPrice * (10 ** 18));
        assertEq(_newName, newName);
        assertEq(_newRecipient, newRecipient);
    }

    function test_PayShipment() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        vm.deal(recipient, 5 ether);

        vm.startPrank(recipient);
        supplyChain.payShipment{value: 1 ether}(1);
        vm.stopPrank();

        uint256 afterBalance = address(supplyChain).balance;

        assertEq(afterBalance, price * (10 ** 18));
    }

    function test_ApproveShipment() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        vm.deal(recipient, 5 ether);

        vm.startPrank(recipient);
        supplyChain.payShipment{value: 1 ether}(1);
        vm.stopPrank();

        vm.warp(block.timestamp);
        supplyChain.approveShipment(1);

        (, , uint256 _completeTime, , , , ) = supplyChain.shipments(1);
        assertEq(_completeTime, block.timestamp + 100000);
    }

    function test_CompleteShipmentRecipient() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        vm.deal(recipient, 5 ether);

        uint256 recipientInitialBalance = address(recipient).balance;
        uint256 senderInitialBalance = address(this).balance;
        uint256 contractInitialBalance = address(supplyChain).balance;

        vm.startPrank(recipient);
        supplyChain.payShipment{value: 1 ether}(1);
        vm.stopPrank();

        vm.warp(block.timestamp);
        supplyChain.approveShipment(1);

        vm.startPrank(recipient);
        supplyChain.completeShipment(1);
        vm.stopPrank();

        uint256 recipientAfterBalance = address(recipient).balance;
        uint256 senderAfterBalance = address(this).balance;
        uint256 contractAfterBalance = address(supplyChain).balance;

        assertEq(
            recipientInitialBalance,
            recipientAfterBalance + price * (10 ** 18)
        );
        assertEq(senderInitialBalance, senderAfterBalance - price * (10 ** 18));
        assertEq(contractInitialBalance, contractAfterBalance);
    }

    function test_CompleteShipmentSender() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        vm.deal(recipient, 5 ether);

        uint256 recipientInitialBalance = address(recipient).balance;
        uint256 senderInitialBalance = address(this).balance;
        uint256 contractInitialBalance = address(supplyChain).balance;

        vm.startPrank(recipient);
        supplyChain.payShipment{value: 1 ether}(1);
        vm.stopPrank();

        vm.warp(block.timestamp);
        supplyChain.approveShipment(1);

        vm.warp(block.timestamp + 110000);
        supplyChain.completeShipment(1);

        uint256 recipientAfterBalance = address(recipient).balance;
        uint256 senderAfterBalance = address(this).balance;
        uint256 contractAfterBalance = address(supplyChain).balance;

        assertEq(
            recipientInitialBalance,
            recipientAfterBalance + price * (10 ** 18)
        );
        assertEq(senderInitialBalance, senderAfterBalance - price * (10 ** 18));
        assertEq(contractInitialBalance, contractAfterBalance);
    }

    function test_CancelShipment() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        vm.deal(recipient, 2 ether);

        vm.startPrank(recipient);
        supplyChain.payShipment{value: 1 ether}(1);

        uint256 initialBalance = address(recipient).balance;

        supplyChain.cancelShipment(1);
        vm.stopPrank();

        uint256 afterBalance = address(recipient).balance;

        assertEq(initialBalance, afterBalance - 1 ether);
    }

    ////////////////////
    //// ERROR TEST ////
    ////////////////////

    ///// CREATE SHIPMENT /////
    function test_RecipientAddressIsSame() public {
        uint256 price = 1;
        string memory name = "Shoes";

        vm.expectRevert(bytes("Recipient address same as sender address!"));
        supplyChain.createShipment(price, name, address(this));
    }

    function test_MustSetProperPrice() public {
        uint256 price = 0;
        string memory name = "Shoes";
        address alex = address(0x123);

        vm.expectRevert(bytes("Please set a proper price!"));
        supplyChain.createShipment(price, name, alex);
    }

    ///// CHANGE SHIPMENT /////
    function test_ShipmentMustExisting() public {
        uint256 id = 2;
        uint256 price = 1;
        string memory name = "Shoes";
        address alex = address(0x123);

        vm.expectRevert(Supplychain.ShipmentNotExist.selector);
        supplyChain.changeShipment(id, price, name, alex);
    }

    function test_MustSender() public {
        // Setup
        uint256 price = 1;
        string memory name = "Shoes";
        address alex = address(0x123);

        supplyChain.createShipment(price, name, alex);

        // Testing
        uint256 id = 1;

        vm.startPrank(alex);
        vm.expectRevert(Supplychain.NotShipmentSender.selector);
        supplyChain.changeShipment(id, price, name, alex);
        vm.stopPrank();
    }

    function test_ShipmentStatusNotMatch() public {
        // Setup
        uint256 price = 1;
        string memory name = "Shoes";
        address alex = address(0x123);

        supplyChain.createShipment(price, name, alex);
        supplyChain.cancelShipment(1);

        // Testing
        vm.expectRevert(Supplychain.NotOrderedStatus.selector);
        supplyChain.changeShipment(1, price, name, alex);
    }

    ///// PAY SHIPMENT /////
    function test_MustRecipient() public {
        // Setup
        uint256 price = 1;
        string memory name = "Shoes";
        address alex = address(0x123);

        supplyChain.createShipment(price, name, alex);

        // Testing
        uint256 id = 1;

        vm.expectRevert(Supplychain.NotShipmentRecipient.selector);
        supplyChain.payShipment{value: 1 ether}(id);
    }

    function test_PaymentIsLessOrMoreThanPrice() public {
        // Setup
        uint256 price = 1;
        string memory name = "Shoes";
        address alex = address(0x123);

        supplyChain.createShipment(price, name, alex);

        // Testing
        uint256 id = 1;

        vm.startPrank(alex);
        vm.expectRevert(bytes("Payment is less or more than the price!"));
        supplyChain.payShipment{value: 0}(id);
    }

    ///// APPROVE SHIPMENT /////
    function test_ErrorCompleteShipmentSender() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        vm.deal(recipient, 5 ether);

        vm.startPrank(recipient);
        supplyChain.payShipment{value: 1 ether}(1);
        vm.stopPrank();

        vm.warp(block.timestamp);
        supplyChain.approveShipment(1);

        vm.warp(block.timestamp + 110000);
        vm.startPrank(address(0x587));
        vm.expectRevert(
            bytes("Only the recipient or sender can complete this shipment")
        );
        supplyChain.completeShipment(1);
        vm.stopPrank();
    }

    function test_ErrorCompleteShipmentRecipient() public {
        uint256 price = 1;
        string memory name = "Shoes";
        address recipient = address(0x123);

        supplyChain.createShipment(price, name, recipient);

        vm.deal(recipient, 5 ether);

        vm.startPrank(recipient);
        supplyChain.payShipment{value: 1 ether}(1);
        vm.stopPrank();

        vm.warp(block.timestamp);
        supplyChain.approveShipment(1);

        vm.startPrank(address(0x587));
        vm.expectRevert(bytes("Only the recipient can complete this shipment"));
        supplyChain.completeShipment(1);
        vm.stopPrank();
    }
}
