// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Supplychain {
    ////////////////////
    ///// VARIABLE /////
    ////////////////////

    error ShipmentNotExist();
    error NotShipmentSender();
    error NotShipmentRecipient();
    error NotOrderedStatus();
    error NotShippedStatus();
    error NotDeliveredStatus();
    error ShipmentHasComplete();
    error ShipmentHasBeenCancelled();

    uint256 id;

    event CreateShipment(
        uint256 id,
        uint256 createTime,
        uint256 price,
        string name,
        address indexed sender,
        address indexed recipient,
        Status status
    );

    event ChangeShipment(
        uint256 shipmentId,
        uint256 changeTime,
        uint256 price,
        string name,
        address indexed sender,
        address indexed recipient
    );

    event Pay(
        uint256 shipmentId,
        uint256 payTime,
        uint256 payValue,
        address indexed payer,
        Status status
    );

    event Approve(
        uint256 shipmentId,
        uint256 approveTime,
        address indexed sender,
        Status status
    );

    event CompletedShipment(
        uint256 shipmentId,
        uint256 completeTime,
        address indexed approvee,
        Status status
    );

    event CancelledShipment(
        uint256 shipmentId,
        uint256 completeTime,
        Status status
    );

    enum Status {
        Ordered,
        Shipped,
        Delivered,
        Completed,
        Cancelled
    }

    constructor() {
        id = 1;
    }

    struct Shipment {
        uint256 id;
        uint256 price;
        uint256 complateTime;
        string name;
        address sender;
        address recipient;
        Status status;
    }

    mapping(uint256 => Shipment) public shipments;

    ////////////////////
    ///// MODIFIER /////
    ////////////////////

    modifier ExistingShipment(uint256 _shipmentId) {
        if (_shipmentId > id - 1) {
            revert ShipmentNotExist();
        }
        _;
    }

    modifier NotSender(uint256 _shipmentId) {
        if (msg.sender != shipments[_shipmentId].sender) {
            revert NotShipmentSender();
        }
        _;
    }

    modifier NotRecipient(uint256 _shipmentId) {
        if (msg.sender != shipments[_shipmentId].recipient) {
            revert NotShipmentRecipient();
        }
        _;
    }

    modifier OrderedStatus(uint256 _shipmentId) {
        if (shipments[_shipmentId].status != Status.Ordered) {
            revert NotOrderedStatus();
        }
        _;
    }

    modifier ShippedStatus(uint256 _shipmentId) {
        if (shipments[_shipmentId].status != Status.Shipped) {
            revert NotShippedStatus();
        }
        _;
    }

    modifier DeliveredStatus(uint256 _shipmentId) {
        if (shipments[_shipmentId].status != Status.Delivered) {
            revert NotDeliveredStatus();
        }
        _;
    }

    modifier CompleteStatus(uint256 _shipmentId) {
        if (shipments[_shipmentId].status == Status.Completed) {
            revert ShipmentHasComplete();
        }
        _;
    }

    modifier CancelledStatus(uint256 _shipmentId) {
        if (shipments[_shipmentId].status == Status.Cancelled) {
            revert ShipmentHasBeenCancelled();
        }
        _;
    }

    ////////////////////
    ///// FUNCTION /////
    ////////////////////

    receive() external payable {}

    fallback() external payable {}

    function createShipment(
        uint256 _price,
        string calldata _name,
        address _recipient
    ) external {
        require(
            _recipient != msg.sender,
            "Recipient address same as sender address!"
        );

        uint256 convertPrice = _price * (10 ** 18);

        require(convertPrice > 0 ether, "Please set a proper price!");

        shipments[id] = Shipment({
            id: id,
            price: convertPrice,
            complateTime: 0,
            name: _name,
            sender: msg.sender,
            recipient: _recipient,
            status: Status.Ordered
        });

        id++;

        emit CreateShipment(
            id - 1,
            block.timestamp,
            _price,
            _name,
            msg.sender,
            _recipient,
            Status.Ordered
        );
    }

    function changeShipment(
        uint256 _shipmentId,
        uint256 _price,
        string calldata _name,
        address _recipient
    )
        external
        ExistingShipment(_shipmentId)
        NotSender(_shipmentId)
        OrderedStatus(_shipmentId)
        CompleteStatus(_shipmentId)
        CancelledStatus(_shipmentId)
    {
        require(
            _recipient != shipments[_shipmentId].sender,
            "Recipient address same as sender address!"
        );

        uint256 convertPrice = _price * (10 ** 18);

        require(convertPrice > 0 ether, "Please set a proper price!");

        shipments[_shipmentId].price = convertPrice;
        shipments[_shipmentId].name = _name;
        shipments[_shipmentId].recipient = _recipient;

        emit ChangeShipment(
            _shipmentId,
            block.timestamp,
            _price,
            _name,
            msg.sender,
            _recipient
        );
    }

    function payShipment(
        uint256 _shipmentId
    )
        external
        payable
        ExistingShipment(_shipmentId)
        NotRecipient(_shipmentId)
        OrderedStatus(_shipmentId)
        CompleteStatus(_shipmentId)
        CancelledStatus(_shipmentId)
    {
        require(
            msg.value == shipments[_shipmentId].price,
            "Payment is less or more than the price!"
        );

        (bool sent, ) = address(this).call{value: msg.value}(" ");
        require(sent, "Transaction failed!");

        shipments[_shipmentId].status = Status.Shipped;

        emit Pay(
            _shipmentId,
            block.timestamp,
            msg.value,
            msg.sender,
            Status.Shipped
        );
    }

    function approveShipment(
        uint256 _shipmentId
    )
        external
        ExistingShipment(_shipmentId)
        NotSender(_shipmentId)
        ShippedStatus(_shipmentId)
        CompleteStatus(_shipmentId)
        CancelledStatus(_shipmentId)
    {
        shipments[_shipmentId].status = Status.Delivered;
        shipments[_shipmentId].complateTime = block.timestamp + 100000;

        emit Approve(
            _shipmentId,
            block.timestamp,
            msg.sender,
            Status.Delivered
        );
    }

    function completeShipment(
        uint256 _shipmentId
    )
        external
        ExistingShipment(_shipmentId)
        DeliveredStatus(_shipmentId)
        CompleteStatus(_shipmentId)
        CancelledStatus(_shipmentId)
    {
        uint256 value = shipments[_shipmentId].price;
        address sender = shipments[_shipmentId].sender;

        if (block.timestamp <= shipments[_shipmentId].complateTime) {
            require(
                msg.sender == shipments[_shipmentId].recipient,
                "Only the recipient can complete this shipment"
            );
            (bool success, ) = sender.call{value: value}("");
            require(success, "Transaction failed!");

            shipments[_shipmentId].status = Status.Completed;
        }

        if (block.timestamp >= shipments[_shipmentId].complateTime) {
            require(
                msg.sender == shipments[_shipmentId].sender,
                "Only the recipient or sender can complete this shipment"
            );
            (bool success, ) = sender.call{value: value}("");
            require(success, "Transaction failed!");

            shipments[_shipmentId].status = Status.Completed;
        }

        emit CompletedShipment(
            _shipmentId,
            block.timestamp,
            msg.sender,
            Status.Completed
        );
    }

    function cancelShipment(
        uint256 _shipmentId
    )
        external
        ExistingShipment(_shipmentId)
        NotRecipient(_shipmentId)
        CompleteStatus(_shipmentId)
    {
        uint256 value = shipments[_shipmentId].price;
        address recipient = shipments[_shipmentId].recipient;

        if (
            shipments[_shipmentId].status == Status.Shipped ||
            shipments[_shipmentId].status == Status.Delivered
        ) {
            (bool success, ) = recipient.call{value: value}("");
            require(success, "Transaction failed");

            shipments[_shipmentId].status = Status.Cancelled;
        }

        shipments[_shipmentId].status = Status.Cancelled;

        emit CancelledShipment(_shipmentId, block.timestamp, Status.Cancelled);
    }

    function getShipmentStatus(
        uint256 _shipmentId
    ) external view returns (Status status) {
        return shipments[_shipmentId].status;
    }

    function getShipmentData(
        uint256 _shipmentId
    ) external view returns (Shipment memory) {
        return shipments[_shipmentId];
    }
}
